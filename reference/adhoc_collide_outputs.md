# Group output files and return the colliding groups

Shared by \[adhoc_output_collisions()\] and
\[adhoc_output_collisions_heuristic()\]: normalizes paths for comparison
(forward slashes; case-insensitive on Windows) and groups them.

## Usage

``` r
adhoc_collide_outputs(outputs)
```

## Arguments

- outputs:

  Named character vector: format name -\> output file.

## Value

\`NULL\` if every output file is unique, else a list of collision
entries (each \`list(file = ..., formats = ...)\`).
