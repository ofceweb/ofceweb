# Set a scalar at a dotted YAML path, or delete it if \`value\` is \`NULL\`

Convenience wrapper around \[yaml_patch_scalar()\] /
\[yaml_patch_delete()\] for call sites where the target value is
sometimes absent by design (e.g. a WP's \`wp:\` key is \`NULL\` for
drafts).

## Usage

``` r
yaml_patch_scalar_or_delete(lines, path, value)
```

## Arguments

- lines:

  Character vector of file lines.

- path:

  Dotted path to the key, e.g. \`"wp"\` or \`"website.site-path"\`.

- value:

  Length-1 character, numeric, or logical scalar, or \`NULL\` to delete
  the key.

## Value

The updated character vector of lines.
