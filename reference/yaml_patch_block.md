# Replace a whole structural value (list/sequence) at a dotted YAML path

Serializes \`value\` via \[yaml::as.yaml()\] and splices it in place of
the existing subtree at \`path\` (or inserts it if absent), re-indented
to match. Comments \*inside\* the replaced subtree are necessarily lost
(the whole thing is regenerated); comments elsewhere in the file are
untouched. \`value = NULL\` deletes the key instead (see
\[yaml_patch_delete()\]).

## Usage

``` r
yaml_patch_block(lines, path, value)
```

## Arguments

- lines:

  Character vector of file lines.

- path:

  Dotted path to the key.

- value:

  An R list/vector to serialize as the new value, or \`NULL\` to delete
  the key.

## Value

The updated character vector of lines.
