# Heuristic output-file collision guess, frontmatter-only

Fallback used when \[adhoc_output_collisions()\] can't reach quarto
inspect: guesses each format's output file from the frontmatter alone –
explicit \`output-file\` when set, else the document stem with an
extension guessed from the format name. Warn-only material, hence
heuristic.

## Usage

``` r
adhoc_output_collisions_heuristic(index_path)
```

## Arguments

- index_path:

  \`\[character(1)\]\` Absolute path of the document to check. Must be
  run with the enclosing project (temp \`\_quarto.yml\`) as the working
  directory.

## Value

\`NULL\` when no collision is possible or none is found; the scalar
string \`"unverified"\` when quarto inspect fails or its output can't be
parsed (caller should fall back to
\[adhoc_output_collisions_heuristic()\]); otherwise a list of collision
entries, each \`list(file = \<output file\>, formats = \<format
names\>)\`.
