get_yaml <- function(path) {
  lines <- readLines(path)
  delimiters <- grep("^---\\s*$", lines)
  if (!length(delimiters)) {
    yaml_list <- yaml::yaml.load(lines)
    return(yaml_list)
  }
  if (length(delimiters) == 1L)
    stop("cannot find second delimiter, first is on line 1")

  delimiters <- delimiters[1:2]
  yaml_list <- yaml::yaml.load(
    lines[ (delimiters[1]+1):(delimiters[2]-1) ])
  return(yaml_list)
}

put_yaml <- function(yaml, path, insert = NULL, pure = FALSE) {
  non_yaml_lines <- ""
  if(fs::file_exists(path)) {
    lines <- readLines(path)
    delimiters <- grep("^---\\s*$", lines)
    if (!length(delimiters)) {
      new_yaml <- yaml::as.yaml(yaml,
                                indent.mapping.sequence = TRUE,
                                handlers = list(logical = yaml::verbatim_logical))
      writeLines(new_yaml, path)
      return(invisible(path))
    }

    if (length(delimiters) == 1L)
      stop("cannot find second delimiter, first is on line 1")

    if(delimiters[2]<length(lines))
      non_yaml_lines <- lines[(delimiters[2]+1):length(lines)]
  }

  new_yaml <- yaml::as.yaml(yaml,
                            indent.mapping.sequence = TRUE,
                            handlers = list(logical = yaml::verbatim_logical))
  delimiter <- if (pure) "" else "---"
  blank_after_insert <- if (is.null(insert)) NULL else ""
  new_lines <- c(delimiter, new_yaml, delimiter, insert, blank_after_insert, non_yaml_lines)
  writeLines(new_lines, path)
  return(invisible(path))
}
