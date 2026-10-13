# Locate the quarto CLI binary

Prefers a \`quarto\` found on the PATH (what \`system2()\` would resolve
anyway); falls back to the quarto R package's internal locator, which
also knows about RStudio-bundled installs. Reaching into \`quarto:::\`
is a pragmatic last resort: if that internal moves or disappears, we
degrade to the bare name and let \`system2()\` raise the error.

## Usage

``` r
adhoc_quarto_bin()
```

## Value

\`\[character(1)\]\` Path (or bare name) of the quarto CLI binary.
