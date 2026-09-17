# Preview a rendered ad-hoc folder site locally

Launches a live preview server on the \`\_site/\` folder via
\[servr::httw()\], allowing real-time browser refresh as files change.
Works any time after \[render_flash()\] has produced \`\_site/\`,
including mid-iteration (re-running \`render_flash()\` while preview is
active auto-reloads the browser tab).

## Usage

``` r
preview_flash(path = ".")
```

## Arguments

- path:

  \`\[character(1)\]\`  
  Folder containing the \`\_site/\` directory. Defaults to \`"."\`.

## Value

Invisibly returns \`NULL\`. Starts a daemon server.

## See also

\[render_flash()\], \[preview_qmd()\]
