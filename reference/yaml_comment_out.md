# Comment out a key (and its subtree) at a dotted YAML path

Prefixes every line of the key's own line and its value/subtree with \`#
\` (respecting each line's existing indentation), disabling it without
deleting its content — a human can later restore it by removing the \`#
\` prefixes. No-op if \`path\` doesn't exist, or if its first line is
already commented out.

## Usage

``` r
yaml_comment_out(lines, path)
```

## Arguments

- lines:

  Character vector of file lines.

- path:

  Dotted path to the key, e.g. \`"format.wp-pdf"\`.

## Value

The updated character vector of lines.
