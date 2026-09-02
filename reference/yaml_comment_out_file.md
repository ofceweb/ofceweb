# Comment out a key inside a plain YAML file on disk

Like \[yaml_comment_out()\], but reads/writes \`path\` directly — for a
project-level file such as \`\_quarto.yml\`, as opposed to a
\`.qmd\`/\`.Rmd\` frontmatter block (see
\[yaml_comment_out_frontmatter()\]).

## Usage

``` r
yaml_comment_out_file(path, key_path)
```

## Arguments

- path:

  Path to a plain YAML file.

- key_path:

  Dotted path to the key.

## Value

Invisibly, \`TRUE\` if the file was changed, \`FALSE\` otherwise (key
absent, or already commented out).
