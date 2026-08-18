# Comment- and layout-preserving YAML editing primitives.
#
# yaml::read_yaml()/write_yaml() round-trip a YAML file through a plain R
# list: comments, blank-line spacing, key ordering, and quoting style are
# all lost on write. The functions below instead edit the raw text lines of
# a YAML file in place, touching only the specific key requested and
# leaving everything else byte-identical. They are deliberately narrow: a
# small indentation-based scanner, not a general YAML parser, and only
# understand plain block-style mappings/sequences (the style used
# throughout the package's own `_quarto.yml` templates).
#
# Used by setup_wp(), setup_prev(), setup_site() and update_navbar() to
# edit `_quarto.yml` (and friends) without discarding a user's comments.

# Returns the number of leading spaces of `line` (0 for blank lines).
yaml_indent_of <- function(line) {
  nchar(regmatches(line, regexpr("^ *", line)))
}

# Escapes a literal key for use inside a regular expression.
yaml_key_regex <- function(key) {
  gsub("([.^$|()\\[\\]{}*+?\\\\])", "\\\\\\1", key, perl = TRUE)
}

# Index (in `lines`) of the last line belonging to the value/subtree that
# starts on `key_line`, which is at indentation `indent`. Blank lines are
# folded in while scanning, but trailing blank lines are trimmed back off
# so callers don't accidentally swallow spacer lines between sections.
yaml_block_end <- function(lines, key_line, indent) {
  n <- length(lines)
  j <- key_line + 1L
  while (j <= n && (!nzchar(trimws(lines[[j]])) || yaml_indent_of(lines[[j]]) > indent)) {
    j <- j + 1L
  }
  end <- j - 1L
  while (end > key_line && !nzchar(trimws(lines[[end]]))) end <- end - 1L
  end
}

# Finds a top-level (column 0) `key:` line. Returns the line index, or NA.
yaml_find_top_level <- function(lines, key) {
  pat <- paste0("^", yaml_key_regex(key), ":(\\s|$)")
  idx <- grep(pat, lines)
  if (length(idx) == 0L) return(NA_integer_)
  idx[[1L]]
}

# Finds a direct child `key:` inside the block [parent_line+1, parent_end],
# whatever indentation that block's children happen to use. Returns a list
# with $found and, when found, $line/$indent; when not found, $child_indent
# reports the indentation direct children of this block use (NA if the
# block is currently empty), so callers know where to insert a new one.
yaml_find_child <- function(lines, parent_line, parent_end, key) {
  if (parent_line >= parent_end) return(list(found = FALSE, child_indent = NA_integer_))
  rng <- (parent_line + 1L):parent_end
  nonblank <- rng[nzchar(trimws(lines[rng]))]
  if (length(nonblank) == 0L) return(list(found = FALSE, child_indent = NA_integer_))
  child_indent <- yaml_indent_of(lines[[nonblank[[1L]]]])
  pat <- paste0("^ {", child_indent, "}", yaml_key_regex(key), ":(\\s|$)")
  hit <- rng[grepl(pat, lines[rng])]
  if (length(hit) == 0L) return(list(found = FALSE, child_indent = child_indent))
  list(found = TRUE, line = hit[[1L]], indent = child_indent)
}

# Locates a dotted `path` (e.g. "website.site-path") in `lines`.
#
# On success: list(found = TRUE, line, indent, end) where [line, end] is
# the full range of the key's own line plus its value/subtree.
#
# On failure: list(found = FALSE, missing_from, ...) with enough context
# (parent_line/parent_end/parent_indent/child_indent, or nothing at all
# when even the top-level segment is missing) for a caller to insert the
# missing chain of keys.
yaml_locate <- function(lines, path) {
  segments <- strsplit(path, ".", fixed = TRUE)[[1L]]

  top_line <- yaml_find_top_level(lines, segments[[1L]])
  if (is.na(top_line)) {
    return(list(found = FALSE, missing_from = 1L))
  }

  cur_line   <- top_line
  cur_indent <- 0L
  cur_end    <- yaml_block_end(lines, cur_line, cur_indent)

  if (length(segments) == 1L) {
    return(list(found = TRUE, line = cur_line, indent = cur_indent, end = cur_end))
  }

  for (i in 2:length(segments)) {
    child <- yaml_find_child(lines, cur_line, cur_end, segments[[i]])
    if (!isTRUE(child$found)) {
      return(list(
        found = FALSE, missing_from = i,
        parent_line = cur_line, parent_end = cur_end, parent_indent = cur_indent,
        child_indent = child$child_indent
      ))
    }
    cur_line   <- child$line
    cur_indent <- child$indent
    cur_end    <- yaml_block_end(lines, cur_line, cur_indent)
  }

  list(found = TRUE, line = cur_line, indent = cur_indent, end = cur_end)
}

# Drops trailing blank lines from a character vector.
yaml_trim_trailing_blank <- function(lines) {
  while (length(lines) > 0L && !nzchar(trimws(lines[[length(lines)]]))) {
    lines <- lines[-length(lines)]
  }
  lines
}

# Builds the lines needed to create a missing key chain, e.g. for
# segments = c("citation", "url"), missing_from = 1, start_indent = 0,
# leaf = "url: https://...": c("citation:", "  url: https://...").
yaml_build_chain <- function(segments, missing_from, start_indent, leaf) {
  n <- length(segments)
  out <- character(0)
  indent <- start_indent
  if (missing_from < n) {
    for (i in missing_from:(n - 1L)) {
      out <- c(out, paste0(strrep(" ", indent), segments[[i]], ":"))
      indent <- indent + 2L
    }
  }
  c(out, paste0(strrep(" ", indent), leaf))
}

# Inserts a missing key chain described by a failed `yaml_locate()` result
# (`loc`), with `leaf` as the text of the final segment's own line (without
# leading indentation — that's added here).
yaml_insert_missing <- function(lines, loc, segments, leaf) {
  if (identical(loc$missing_from, 1L)) {
    chain <- yaml_build_chain(segments, 1L, 0L, leaf)
    return(c(yaml_trim_trailing_blank(lines), chain))
  }
  start_indent <- if (!is.na(loc$child_indent)) loc$child_indent else loc$parent_indent + 2L
  chain <- yaml_build_chain(segments, loc$missing_from, start_indent, leaf)
  append(lines, chain, after = loc$parent_end)
}

# Renders a length-1 scalar the way it would appear after a `key: ` prefix,
# reusing yaml::as.yaml()'s quoting/escaping rules rather than
# reimplementing them. Falls back to a manually single-quoted string if
# as.yaml() would need a block/multiline representation (not expressible
# on a single `key: value` line).
yaml_scalar_repr <- function(value) {
  if (is.null(value))
    stop("yaml_scalar_repr(): value is NULL; use yaml_patch_delete() to remove a key.")
  if (is.logical(value))
    return(if (isTRUE(value)) "true" else "false")
  if (is.numeric(value))
    return(format(value, trim = TRUE, scientific = FALSE))
  if (!is.character(value) || length(value) != 1L)
    stop("yaml_scalar_repr(): value must be a length-1 character, numeric, or logical.")

  raw <- sub("\n$", "", yaml::as.yaml(value))
  if (grepl("\n", raw, fixed = TRUE)) {
    # A block/multiline scalar can't be expressed on a single `key: value`
    # line; fall back to a double-quoted string with escaped control chars.
    escaped <- value
    escaped <- gsub("\\", "\\\\", escaped, fixed = TRUE)
    escaped <- gsub("\"", "\\\"", escaped, fixed = TRUE)
    escaped <- gsub("\n", "\\n", escaped, fixed = TRUE)
    escaped <- gsub("\t", "\\t", escaped, fixed = TRUE)
    escaped <- gsub("\r", "\\r", escaped, fixed = TRUE)
    raw <- paste0("\"", escaped, "\"")
  }
  raw
}

#' Set a scalar value at a dotted YAML path, preserving the rest of the file
#'
#' Edits `lines` (as returned by `readLines()`) in place to set the scalar
#' at `path` (e.g. `"website.site-path"`) to `value`, touching only that
#' key's own line. Missing intermediate mapping keys are created as needed,
#' appended at the end of the relevant parent block (or end of file for a
#' brand-new top-level key).
#'
#' @param lines Character vector of file lines.
#' @param path Dotted path to the key, e.g. `"wp"` or `"website.site-path"`.
#' @param value Length-1 character, numeric, or logical scalar.
#' @returns The updated character vector of lines.
yaml_patch_scalar <- function(lines, path, value) {
  segments <- strsplit(path, ".", fixed = TRUE)[[1L]]
  key      <- segments[[length(segments)]]
  repr     <- yaml_scalar_repr(value)
  leaf     <- paste0(key, ": ", repr)

  loc <- yaml_locate(lines, path)
  if (isTRUE(loc$found)) {
    new_line <- paste0(strrep(" ", loc$indent), leaf)
    before <- if (loc$line > 1L) lines[seq_len(loc$line - 1L)] else character(0)
    after  <- if (loc$end < length(lines)) lines[(loc$end + 1L):length(lines)] else character(0)
    return(c(before, new_line, after))
  }
  yaml_insert_missing(lines, loc, segments, leaf)
}

#' Set a scalar at a dotted YAML path, or delete it if `value` is `NULL`
#'
#' Convenience wrapper around [yaml_patch_scalar()] / [yaml_patch_delete()]
#' for call sites where the target value is sometimes absent by design
#' (e.g. a WP's `wp:` key is `NULL` for drafts).
#'
#' @inheritParams yaml_patch_scalar
#' @param value Length-1 character, numeric, or logical scalar, or `NULL`
#'   to delete the key.
#' @returns The updated character vector of lines.
yaml_patch_scalar_or_delete <- function(lines, path, value) {
  if (is.null(value)) yaml_patch_delete(lines, path) else yaml_patch_scalar(lines, path, value)
}

#' Delete a key (and its subtree) at a dotted YAML path
#'
#' No-op if the path doesn't exist. Only the key's own line range is
#' removed; blank lines or comments immediately adjacent to it are left
#' untouched.
#'
#' @param lines Character vector of file lines.
#' @param path Dotted path to the key.
#' @returns The updated character vector of lines.
yaml_patch_delete <- function(lines, path) {
  loc <- yaml_locate(lines, path)
  if (!isTRUE(loc$found)) return(lines)
  lines[-(loc$line:loc$end)]
}

#' Replace a whole structural value (list/sequence) at a dotted YAML path
#'
#' Serializes `value` via [yaml::as.yaml()] and splices it in place of the
#' existing subtree at `path` (or inserts it if absent), re-indented to
#' match. Comments *inside* the replaced subtree are necessarily lost (the
#' whole thing is regenerated); comments elsewhere in the file are
#' untouched. `value = NULL` deletes the key instead (see
#' [yaml_patch_delete()]).
#'
#' @param lines Character vector of file lines.
#' @param path Dotted path to the key.
#' @param value An R list/vector to serialize as the new value, or `NULL`
#'   to delete the key.
#' @returns The updated character vector of lines.
yaml_patch_block <- function(lines, path, value) {
  if (is.null(value)) return(yaml_patch_delete(lines, path))

  segments <- strsplit(path, ".", fixed = TRUE)[[1L]]
  key      <- segments[[length(segments)]]

  wrapped <- list(value)
  names(wrapped) <- key
  raw <- yaml::as.yaml(
    wrapped,
    indent.mapping.sequence = TRUE,
    handlers = list(logical = yaml::verbatim_logical)
  )
  raw_lines <- strsplit(raw, "\n", fixed = TRUE)[[1L]]
  raw_lines <- raw_lines[nzchar(raw_lines)]

  loc <- yaml_locate(lines, path)
  if (isTRUE(loc$found)) {
    indented <- paste0(strrep(" ", loc$indent), raw_lines)
    before <- if (loc$line > 1L) lines[seq_len(loc$line - 1L)] else character(0)
    after  <- if (loc$end < length(lines)) lines[(loc$end + 1L):length(lines)] else character(0)
    return(c(before, indented, after))
  }

  # Build any missing intermediate mapping headers (e.g. `navbar:` when
  # patching "website.navbar.left" and `navbar:` doesn't exist yet) before
  # the serialized `raw_lines`, which already carries the final segment's
  # own `key:` line.
  start_indent <- if (identical(loc$missing_from, 1L)) {
    0L
  } else if (!is.na(loc$child_indent)) {
    loc$child_indent
  } else {
    loc$parent_indent + 2L
  }
  headers <- character(0)
  indent  <- start_indent
  if (loc$missing_from < length(segments)) {
    for (i in loc$missing_from:(length(segments) - 1L)) {
      headers <- c(headers, paste0(strrep(" ", indent), segments[[i]], ":"))
      indent  <- indent + 2L
    }
  }
  indented <- c(headers, paste0(strrep(" ", indent), raw_lines))

  if (identical(loc$missing_from, 1L)) {
    c(yaml_trim_trailing_blank(lines), indented)
  } else {
    append(lines, indented, after = loc$parent_end)
  }
}

#' Patch a scalar inside a `.qmd`/`.Rmd` file's YAML frontmatter
#'
#' Like [yaml_patch_scalar()], but operates on the `---`-delimited
#' frontmatter block of a file on disk: the document body, and any
#' comments/layout in the frontmatter outside the patched key, are left
#' untouched.
#'
#' @param path Path to a `.qmd`/`.Rmd` file with `---`-delimited frontmatter.
#' @param key_path Dotted path to the key within the frontmatter.
#' @param value Length-1 character, numeric, or logical scalar.
#' @returns Invisibly, `path`.
yaml_patch_frontmatter_scalar <- function(path, key_path, value) {
  lines <- readLines(path, warn = FALSE)
  delimiters <- grep("^---\\s*$", lines)
  if (length(delimiters) < 2L)
    stop("yaml_patch_frontmatter_scalar(): no YAML frontmatter delimiters found in ", path)

  fm_range <- (delimiters[[1L]] + 1L):(delimiters[[2L]] - 1L)
  fm <- if (length(fm_range) > 0L) lines[fm_range] else character(0)
  fm <- yaml_patch_scalar(fm, key_path, value)

  before <- lines[seq_len(delimiters[[1L]])]
  after  <- lines[delimiters[[2L]]:length(lines)]
  writeLines(c(before, fm, after), path)
  invisible(path)
}
