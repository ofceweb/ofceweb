# Predict output-file collisions between the formats of a document

A document declaring 2+ formats renders all of them; when two formats
resolve to the same output file, quarto's project step crashes with a
cryptic \`NotFound ... rename\` error (the first format's move into the
output dir consumes the file, the second has nothing left to move). This
asks \`quarto inspect\` for each format's \*resolved\* output file –
defaults included – so a reported collision is deterministic, never a
false positive.

## Usage

``` r
adhoc_output_collisions(index_path)
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

## Details

Only runs the inspect call when the document's frontmatter declares 2+
formats (single-format documents can never collide), keeping the common
case free of the extra CLI round-trip.
