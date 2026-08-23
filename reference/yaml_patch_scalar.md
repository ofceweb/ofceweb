# Set a scalar value at a dotted YAML path, preserving the rest of the file

Edits \`lines\` (as returned by \`readLines()\`) in place to set the
scalar at \`path\` (e.g. \`"website.site-path"\`) to \`value\`, touching
only that key's own line. Missing intermediate mapping keys are created
as needed, appended at the end of the relevant parent block (or end of
file for a brand-new top-level key).

## Usage

``` r
yaml_patch_scalar(lines, path, value)
```

## Arguments

- lines:

  Character vector of file lines.

- path:

  Dotted path to the key, e.g. \`"wp"\` or \`"website.site-path"\`.

- value:

  Length-1 character, numeric, or logical scalar.

## Value

The updated character vector of lines.
