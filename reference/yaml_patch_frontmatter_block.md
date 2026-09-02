# Patch a structural value (list/sequence) inside a \`.qmd\`/\`.Rmd\` file's YAML frontmatter

Like \[yaml_patch_block()\], but operates on the \`—\`-delimited
frontmatter block of a file on disk: the document body, and any
comments/layout in the frontmatter outside the patched key, are left
untouched.

## Usage

``` r
yaml_patch_frontmatter_block(path, key_path, value)
```

## Arguments

- path:

  Path to a \`.qmd\`/\`.Rmd\` file with \`—\`-delimited frontmatter.

- key_path:

  Dotted path to the key within the frontmatter.

- value:

  An R list/vector to serialize as the new value, or \`NULL\` to delete
  the key.

## Value

Invisibly, \`path\`.
