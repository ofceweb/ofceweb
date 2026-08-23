# Delete a key (and its subtree) at a dotted YAML path

No-op if the path doesn't exist. Only the key's own line range is
removed; blank lines or comments immediately adjacent to it are left
untouched.

## Usage

``` r
yaml_patch_delete(lines, path)
```

## Arguments

- lines:

  Character vector of file lines.

- path:

  Dotted path to the key.

## Value

The updated character vector of lines.
