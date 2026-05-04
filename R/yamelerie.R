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
  new_lines <- character()
  if(!pure)
    new_lines[1] <- "---"
  else
    new_lines[1] <- ""
  new_lines[2] <- new_yaml
  if(!pure)
    new_lines[3] <- "---"
  else
    new_lines[3] <- ""
  if(!is.null(insert)) {
    for( i in 1:length(insert) ) {
      new_lines[3+i] <- insert[i]
    }
    new_lines[4+length(insert)] <- ""
    new_lines[(5+length(insert)):(5+length(insert)+length(non_yaml_lines)-1)] <- non_yaml_lines
  } else {
    new_lines[4:(3+length(non_yaml_lines))] <- non_yaml_lines
  }
  writeLines(new_lines, path)
  return(invisible(path))
}
