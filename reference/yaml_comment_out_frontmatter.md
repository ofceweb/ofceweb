# Comment out a key inside a \`.qmd\`/\`.Rmd\` file's YAML frontmatter

Like \[yaml_patch_frontmatter_scalar()\], but comments the key out (see
\[yaml_comment_out()\]) rather than setting a new scalar value. The
document body, and any comments/layout in the frontmatter outside the
commented key, are left untouched.

## Usage

``` r
yaml_comment_out_frontmatter(path, key_path)
```

## Arguments

- path:

  Path to a \`.qmd\`/\`.Rmd\` file with \`—\`-delimited frontmatter.

- key_path:

  Dotted path to the key within the frontmatter.

## Value

Invisibly, \`TRUE\` if the file was changed, \`FALSE\` otherwise (key
absent, or already commented out).
