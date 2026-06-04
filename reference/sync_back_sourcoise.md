# Sync back \`.sourcoise/\` directories from rendered copies to source posts

After rendering a language pass, any \`.sourcoise/\` directory that
appeared (or was populated) inside the ephemeral copy folder is mirrored
back to the original \`posts/\` tree. Only files \*\*not already
present\*\* in the target \`.sourcoise/\` are copied, which naturally
deduplicates across the FR and EN passes without extra bookkeeping.

## Usage

``` r
sync_back_sourcoise(cached, lang, max_size_mb = 50)
```

## Arguments

- cached:

  Data frame returned by \[get_from_cache()\]. Must contain at least the
  columns \`from_cache\`, \`origin\` (path to the rendered copy), and
  \`source\` (path to the original post folder under \`posts/\`).

- lang:

  Character. Language label used for cli messages (\`"fr"\` or
  \`"en"\`).

## Value

Invisibly, the total number of files synced back across all posts.
