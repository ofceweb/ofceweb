renv::

editor_options: markdown: wrap: 72 ---

# Plan: central WP registry (admin-declared publish authorization)

Status: **not started** — new design, proposed as the primary path forward for WP publish security, likely superseding the environment/reviewer-gate idea in `2026-08-21-1605-plan-wp-publish-security-phase2.md`.

## Motivation

Phase 1 (implemented, commit `251e662`) blocks a WP repo from overwriting a *live, already-deployed* `manifest.json` whose `source-repo` differs from the current repo. Two gaps remain:

1.  **Bypassable**: a bad actor can dodge the check entirely by picking a `custom_version` string that has never been deployed at that exact path, since the check only compares against what's currently live at the target subpath, not against the `{annee, wp}` pair itself.
2.  **No prior authorization step**: any repo can claim any `{annee, wp}` on its *first* publish — there's nothing preventing two different repos from racing to claim the same number, only from silently overwriting one another after the fact.

The Phase 2 plan explored gating every deploy with a GitHub Environment reviewer rule, but this only works reliably on GitHub Enterprise or on public repositories — OFCE's WP repos are a mix of public/private on GitHub Team, so that approach would give inconsistent protection (see the earlier plan file for details).

**This plan proposes a different mechanism: a central registry repository where an administrator declares which `{annee, wp}` numbers belong to which source repo, and `ftp_deploy.yml` refuses to publish unless the calling repo matches the registered owner.** This closes gap (1) by keying the check on `{annee, wp}` rather than a live manifest at a specific path, and closes gap (2) by requiring registration — an inherently admin-gated action — before any publish can succeed at all. It is also plan-tier/visibility-agnostic: it relies on ordinary PR review / branch protection on the registry repo, not on GitHub Actions Environments, so it works the same way regardless of whether a given WP repo is public or private, or whether the org is on Team or Enterprise.

## Architecture

### Central registry repository

- **Decided 2026-08-22:** new repo `ofceweb/wp-registry` (org: `ofceweb`, not `ofce`), **public**.
- Public visibility means `ftp_deploy.yml` can read it with a plain unauthenticated `curl` to `raw.githubusercontent.com` — no token/secret needs to be distributed to every WP repo just to perform the read-only authorization check. The registry only maps `{annee, wp} → source-repo`, not WP titles/content, so there's little to leak.

### Registry schema

A single `registry.json` (or `registry.yml`) at the repo root, one entry per `{annee, wp}` pair (not per version — this is what closes the `custom_version` bypass).

Two entry `type`s are needed, not just one — see "PDF-only / no-repo WPs" below for why:

``` json
{
  "wp": [
    {
      "annee": 2026,
      "wp": 15,
      "type": "repo",
      "source-repo": "ofce/wp-2026-15-titre-du-document",
      "contact": "prenom.nom@ofce.sciences-po.fr",
      "registered-by": "xtimbeau",
      "registered-at": "2026-08-21"
    },
    {
      "annee": 2019,
      "wp": 4,
      "type": "pdf-only",
      "source-repo": null,
      "contact": null,
      "registered-by": "xtimbeau",
      "registered-at": "2026-08-22"
    }
  ]
}
```

- `type: "repo"` (default, the only kind Phase 1/2 originally considered) — `source-repo` is required and is checked against `github.repository` at publish time, as described below.
- `type: "pdf-only"` — a WP that was (or will be) published as a bare PDF with no Quarto/GitHub Actions pipeline behind it at all. `source-repo` is `null`. Its purpose is purely to **reserve the `{annee, wp}` number** so no repo can later claim it via `ftp_deploy.yml` — see "PDF-only / no-repo WPs" below.
- **`contact` field — added 2026-08-23.** Email (or other reachable identifier, e.g. a GitHub handle) for the WP's author, so the registry admin can follow up about a specific entry (renewal, dispute, migration, deregistration, etc.) without having to dig through the source repo's contributor list. Required for `type: "repo"` entries; populated by a `contact` parameter on `wp_registry_request()` that **defaults to the local `git config user.email`** and can be overridden with an explicit value. `null` is acceptable for `type: "pdf-only"` legacy entries where no live author contact is readily available.

### Multiple/sharded registry files — decided 2026-08-23

**The registry is allowed to be split across more than one file.** Rather than a single `registry.json`, `wp-registry` may hold any number of files matching the pattern `registry-{id}.json` at the repo root (e.g. `registry-2025.json`, `registry-2026.json`) — each holding the same `{"wp": [...]}` shape as the single-file schema above. **Every file matching this pattern is part of one logical registry**: all lookups, collision checks, and auto-numbering must treat the union of entries across every shard file as "the registry," not just one file in isolation.

- **`{id}` is admin-chosen, not derived or enforced by tooling.** The expected common case is one shard per `annee` (as in the example above), but nothing requires that mapping — `{id}` is just a filename discriminator so multiple files can coexist without name collisions. A reviewer merging a new shard file (or a new entry into an existing one) is free to organize shards however makes sense administratively (by year, by a block of WP numbers, etc.).

- **No file is authoritative on its own.** A given `{annee, wp}` pair must appear in **exactly one** shard file across the whole repo — duplicate `{annee, wp}` entries across two different shard files is a data-integrity error, not a valid state (see the CI schema-validation idea below for how to catch this automatically).

- **Enumeration mechanism — open implementation detail, not yet finalized.** Every consumer (`ftp_deploy.yml`, `render_wp()`, `wp_registry_request()`) needs to discover *which* `registry-*.json` files currently exist before it can treat "the registry" as complete, not just fetch one hardcoded filename. Two candidate approaches, to be decided before implementation:

  1.  **GitHub Contents API listing** (`GET /repos/ofceweb/wp-registry/contents/`, filtered client-side to `registry-*.json`) — no extra file to keep in sync, but anonymous/unauthenticated requests are rate-limited (60 req/hour per IP) more tightly than `raw.githubusercontent.com`. Mitigation: both consumer contexts already have a token available for free — GitHub Actions injects `GITHUB_TOKEN` into every workflow run automatically (no new secret to distribute), and local invocations of `wp_registry_request()`/`setup_wp()` can use the user's already-authenticated `gh` CLI — so this needn't reintroduce the "no secrets needed" cost the plan otherwise avoids for the read-only lookup.
  2.  **A maintained index file** (e.g. `registry-index.json`, listing current shard filenames) fetched first via plain unauthenticated `curl` against `raw.githubusercontent.com`, same as a single shard is today. Simpler fetch story (no API auth headers, no rate-limit distinction) but adds a second file an admin/CI must remember to keep in sync whenever a shard is added or removed — a stale index silently hides a shard from every consumer, which is a worse failure mode than a slightly slower listing call.

  - **Leaning towards (1)** given the token availability above, but flagging as an open decision (see new open item below) rather than assuming — needs a quick check of whether `curl`-only consumers (if any remain outside GitHub Actions/`gh`) would be broken by requiring API auth.

- **Consequence for `wp_registry_request()`'s collision/auto-numbering logic** (see signature draft below): "fetch `registry.json`" throughout this plan should be read as "fetch and merge every current `registry-*.json` shard" — both the `{annee, wp}` collision check for an explicit `wp` argument and the `max(existing wp) + 1` auto-numbering logic must scan across all shards for the given `annee`, not just one file.

- **Consequence for governance/CODEOWNERS:** the `CODEOWNERS` pattern protecting registry content (see "Governance" below and the already-implemented `ofceweb/wp-registry` entry) should use a glob covering all shards — `/registry-*.json` and, while the migration below is pending, the original `/registry.json` — rather than naming one exact filename, so a new shard file introduced by a future PR is covered by required review from day one without a separate CODEOWNERS update.

- **Migration of the existing single `registry.json`.** The already-created and populated `ofceweb/wp-registry` repo currently has one file, `registry.json` (4 entries, all `annee` 2025–2026). Options once sharding is implemented: (a) leave it as-is — a single file is a valid degenerate case of "one or more shards," no rename required; or (b) rename it to `registry-2026.json` (or split into per-year shards) for consistency with the new convention. **No decision needed yet** — this only matters once the enumeration mechanism is implemented and can trivially treat today's single file as the one-shard case either way.

### Org-membership requirement (`ofce` only) — decided 2026-08-22

**A WP source repo must live inside the `ofce` GitHub organisation. This is now the sole path to obtaining FTP secrets — no other org or personal-account repo may publish, regardless of registry state.** This tightens the scheme in three concrete ways:

1.  **`ftp_deploy.yml` gets an org-membership check, independent of and prior to the registry lookup.** Before even fetching `registry.json`, the workflow checks `github.repository_owner == 'ofce'` (or equivalently, `github.repository` matches `^ofce/`) and fails immediately with `::error::` if not — *"ftp_deploy.yml may only run from a repository inside the ofce organisation."* This is deliberate defense-in-depth: even if a `type: "repo"` registry entry were ever mistakenly merged with a non-`ofce` `source-repo`, this independent gate still blocks the actual publish. It also means the org-level Tier 1 ruleset (which itself only lives inside `ofce`, per decision 7) automatically covers every repo capable of passing this check.
2.  **Registry entries of `type: "repo"` must have `source-repo` matching `ofce/*`.** This should be enforced both as a documented convention (in `wp-registry`'s `CODEOWNERS`/`README`, checked by the human reviewer) and, ideally, by a CI check in `wp-registry` itself (e.g. a GitHub Actions workflow on `pull_request` that validates `registry.json` against a JSON Schema requiring `source-repo` to start with `ofce/` for `type: "repo"` rows) so a reviewer can't accidentally merge a non-conforming entry.
3.  **`wp_registry_request()` refuses to run from a non-`ofce` repo.** The helper should check the resolved `source-repo` (via `gh_slug_from_remote()`, per the existing pattern in `R/wp_manifest.R`) before opening any PR, and error out locally with a clear message if the repo isn't under `ofce` — rather than opening a PR that a reviewer would just have to reject.

**Consequence for the backfill:** `xtimbeau/travail` (`2025-23`) can no longer be registered as-is — it must be **transferred into `ofce`** first. This is now decision 9 below, not merely "accept weaker protection."

### Governance (how an admin "declares" a WP)

- Branch protection on `wp-registry`'s default branch: disallow direct pushes, require pull request review, and use a `CODEOWNERS` file naming a `wp-admins` team as required reviewers for `registry.json`.
- Branch protection + required PR review is broadly available across GitHub plans (unlike the Environment required-reviewers feature, which needs Enterprise for private repos) — this needs a final confirmation against current GitHub docs before relying on it, but has historically been a long-standing feature independent of the newer Environments gating.
- Only a merged PR (i.e., admin approval) creates a valid registry entry.

### Registration workflow

**Decided 2026-08-22: Option B (semi-automated), for `type: "repo"` entries.** A new helper, working name `wp_registry_request()`, computes `{annee, wp, source-repo}` from the local `_quarto.yml`/`manifest.json` and opens the PR against `ofceweb/wp-registry` automatically (via `gh`/`gert`, consistent with `ofceweb`'s existing git tooling). The human review/merge gate is unchanged; this only removes manual JSON editing and the risk of malformed/mismatched entries. Could be invoked from `setup_wp()` interactively, or as a standalone exported function.

Manual PRs remain the only path for `type: "pdf-only"` entries (no local repo/`_quarto.yml` to automate from) and as a fallback if `wp_registry_request()` isn't available yet or fails.

### `wp_registry_fetch()` — signature draft, sketched 2026-08-24

Shared internal helper (see "New/changed `ofceweb` pieces" above) implementing the "fetch and merge every `registry-*.json` shard" step referenced throughout this plan (publish-time verification, `wp_registry_request()`'s collision/auto-numbering, and the future `render_wp()` registry check). Not exported — called from all three sites so the enumerate/fetch/merge/validate logic lives in exactly one place.

``` r
#' Récupère et fusionne l'ensemble du registre central des WP
#'
#' Énumère tous les fichiers `registry-*.json` présents à la racine de
#' `wp-registry` (voir "Multiple/sharded registry files"), les télécharge et
#' fusionne leurs entrées en une seule liste, en validant au passage que le
#' registre combiné ne contient pas d'incohérence. N'est jamais mise en
#' cache par cette fonction elle-même — chaque appelant décide s'il rappelle
#' cette fonction ou réutilise un résultat déjà en mémoire.
#'
#' @param registry_repo Slug `"owner/repo"` du dépôt registre. Défaut
#'   `"ofceweb/wp-registry"`.
#' @param ref Référence Git à lire (branche, tag ou SHA). Défaut `"HEAD"`
#'   (résolu par l'API Contents vers la branche par défaut).
#' @param strict Si `TRUE` (défaut), une entrée invalide ou une collision
#'   `{annee, wp}` entre deux fichiers fait échouer l'appel avec
#'   `cli::cli_abort()`. Si `FALSE`, les entrées fautives sont ignorées avec
#'   `cli::cli_alert_warning()` et le reste du registre est renvoyé quand
#'   même — pensé pour un contexte non bloquant (ex. un futur
#'   `wp_registry_check()` interactif qui veut afficher un diagnostic sans
#'   interrompre la session R de l'utilisateur·rice).
#'
#' @returns Une `tibble` avec une ligne par entrée du registre combiné et les
#'   colonnes `annee`, `wp`, `type`, `source-repo`, `contact`,
#'   `registered-by`, `registered-at`, plus une colonne interne `.shard`
#'   (nom du fichier d'origine, utile pour un message d'erreur précis en cas
#'   de collision). Une `tibble` plutôt qu'une liste imbriquée, pour rendre
#'   triviaux les filtres/`dplyr::filter()` des appelants (recherche d'un
#'   `{annee, wp}` donné, `max(wp)` par `annee`, etc.).
#' @keywords internal
#' @noRd
wp_registry_fetch <- function(registry_repo = "ofceweb/wp-registry",
                               ref = "HEAD",
                               strict = TRUE) {
  ...
}
```

Sketch of the internal logic:

1.  **Enumerate shard files** via the GitHub Contents API — `gh::gh("GET /repos/{owner}/{repo}/contents/", owner = ..., repo = ..., ref = ref)`, reusing the same `gh::gh()` call already used elsewhere in `R/git_utils.R` (e.g. `collect_gh_files()`), then `purrr::keep()` entries where `type == "file"` and the name matches `^registry-.*\.json$` (or, for backwards compatibility with the single already-deployed file, also accept an exact `registry.json`). `gh::gh()` resolves auth the same way as the rest of the package — `gh::gh_token()`, which transparently picks up `GITHUB_TOKEN` inside a GitHub Actions run or a locally authenticated `gh` CLI, with no code-level branching needed for "authenticated vs. anonymous" (falls back to an unauthenticated request if no token is found anywhere, which still works for a public repo, just at the tighter anonymous rate limit).
2.  **Fetch each shard's content.** Two sub-options, both already used elsewhere in the package: (a) take `download_url` from the same Contents API listing response and `curl::curl_download()`/`httr2::req_perform()` each one (pattern from `download_gh_file()`/`download_gh_dir()` in `R/git_utils.R`), or (b) since the Contents API response for a small file already includes base64-encoded `content` inline, decode that directly (`jsonlite::base64_dec()`) and skip a second round-trip entirely. **(b) is preferred** — these files are small (a handful of KB even with many entries), so avoiding a second HTTP call per shard is a meaningful simplification with no real downside.
3.  **Parse each shard** with `jsonlite::fromJSON(simplifyVector = FALSE)` (parse as nested lists first, not directly into a data frame — some fields, e.g. `contact`, are legitimately `NULL`/`null` and naive `simplifyVector` handling of heterogeneous NULLs across rows is a known footgun) then flatten to a `tibble` row-by-row via `purrr::map_dfr()` (or `dplyr::bind_rows()` over `purrr::map()`), tagging each row's `.shard` with the source filename as it's flattened — needed for validation messages in step 4.
4.  **Validate the combined result** before returning (behavior gated by `strict`):
    - **Required fields present per entry:** `annee` (integer), `wp` (integer), `type` (one of `"repo"`/`"pdf-only"`), `registered-by` (non-empty string), `registered-at` (parseable as a date). Missing/wrong-typed → abort (or warn+drop, if `!strict`) naming the offending `.shard` and entry.
    - **`type`-dependent field requirements:** `type == "repo"` requires non-`NA` `source-repo` matching `^ofce/` (see "Org-membership requirement" above — this is the R-level mirror of the `wp-registry` CI schema check proposed there) and non-`NA` `contact`; `type == "pdf-only"` requires `source-repo` to be `NA`/`null` (a `pdf-only` row with a populated `source-repo` is a contradiction, not just a missing field).
    - **No duplicate `{annee, wp}` across the combined set** — `dplyr::count(annee, wp) |> dplyr::filter(n > 1)`; any duplicates abort naming both `.shard` values involved (this is the cross-shard integrity check "Multiple/sharded registry files" above calls out as needing automated detection, done here at read-time as a client-side safety net alongside — not instead of — the proposed `wp-registry`-side CI check that would catch it before merge).
    - Duplicate-`{annee, wp}` and malformed-entry problems are treated as `strict`-gated errors, **never silently resolved by picking one** (e.g. "last shard wins") — a silent pick would defeat the entire point of the registry as an unambiguous authorization source.
5.  **Return the merged, validated tibble.** Callers do their own filtering (e.g. `dplyr::filter(annee == this_annee, wp == this_wp)` for the publish-time lookup, or `dplyr::filter(annee == this_annee) |> dplyr::summarise(next_wp = max(wp) + 1L)` for `wp_registry_request()`'s auto-numbering) rather than `wp_registry_fetch()` taking a lookup key itself — keeps the helper single-purpose (fetch+validate) and reusable across the three call sites, which each need a different downstream query.

Open follow-ups this sketch surfaces (not yet separately tracked as numbered open decisions, since they're implementation-level rather than design-level):

- Whether `ftp_deploy.yml`'s Actions-side steps call this via `Rscript -e "ofceweb:::wp_registry_fetch(...)"` (consistent with other `ofceweb`-backed steps in that workflow) or whether the lookup is simple enough to keep as inline `gh api`/`jq` shell steps without depending on the R package at all — the latter avoids an R startup cost per deploy but duplicates the merge/validation logic in shell instead of reusing this function. Leaning towards calling into `ofceweb` for consistency and single-sourcing the validation rules, but flagging since it's a real tradeoff.
- Whether `strict = FALSE`'s "warn and drop" behavior is ever actually exercised by a real call site, or whether every current caller (publish-time gate, collision check) actually wants `strict = TRUE` always — the parameter is speculative for a possible future `wp_registry_check()` diagnostic tool (see "New/changed `ofceweb` pieces" above) rather than a confirmed need; fine to drop the parameter and hardcode strict behavior if that tool never materializes.

### `wp_registry_request()` — signature draft, resolved 2026-08-23

``` r
#' Demande d'enregistrement d'un WP dans le registre central
#'
#' Calcule le triplet `{annee, wp, source-repo}` pour le dépôt WP local et
#' ouvre une pull request contre `ofceweb/wp-registry` proposant d'ajouter
#' l'entrée correspondante à `registry.json`. N'attend pas la fusion
#' (fire-and-forget, décision du 2026-08-22) — un·e admin doit approuver
#' manuellement ; relancer `setup_wp()` une fois la PR fusionnée pour que le
#' dépôt bascule de brouillon à publié.
#'
#' @param path Chemin vers la racine du dépôt WP local. Défaut `"."`.
#' @param annee Année du WP. Défaut : `yml$annee` si déjà présent dans
#'   `_quarto.yml`, sinon l'année courante.
#' @param wp Numéro de WP souhaité. Si `NULL` (défaut), calculé
#'   automatiquement comme `max(wp existants pour cette annee) + 1`, tous
#'   types confondus (`repo` et `pdf-only`), d'après `registry.json` tel que
#'   fusionné au moment de l'appel. Si fourni explicitement, la fonction
#'   vérifie d'abord qu'aucune entrée existante n'occupe déjà ce
#'   `{annee, wp}` et échoue localement (sans ouvrir de PR) en cas de
#'   collision.
#' @param contact Adresse de contact de l'auteur·e, stockée dans l'entrée du
#'   registre pour que l'admin puisse recontacter l'auteur·e. Défaut :
#'   `gert::git_config_get("user.email", repo = path)` — résout la config
#'   Git locale du dépôt avec repli automatique sur la config globale si
#'   aucune valeur locale n'est définie (comportement natif de
#'   `git_config_get()`, cohérent avec `git config user.email`). Si cette
#'   résolution ne renvoie rien (aucune config Git locale ou globale), la
#'   fonction échoue avec `cli::cli_abort()` en demandant de fournir
#'   `contact` explicitement plutôt que d'ouvrir une PR avec un contact vide.
#' @param registry_repo Slug `"owner/repo"` du dépôt registre. Défaut
#'   `"ofceweb/wp-registry"`.
#' @param dry_run Si `TRUE`, calcule et affiche l'entrée proposée sans
#'   ouvrir de pull request. Défaut `FALSE`.
#'
#' @returns Invisiblement, une liste avec l'entrée proposée et l'URL de la
#'   PR ouverte (`NULL` en mode `dry_run`).
#' @seealso [setup_wp()], [wp_manifest()]
#' @export
wp_registry_request <- function(path = ".",
                                 annee = NULL,
                                 wp = NULL,
                                 contact = NULL,
                                 registry_repo = "ofceweb/wp-registry",
                                 dry_run = FALSE) {
  ...
}
```

Notes on the sketch above:

- **`contact` resolution order, made explicit:** explicit argument → `git_config_get("user.email", repo = path)` (local, falling back to global per `gert`'s documented local-wins-else-global semantics) → hard failure. There is no silent "leave it blank" path; an entry without a reachable contact defeats the field's purpose (see the `contact` field description above).
- **Org-membership is checked locally too, not just by `ftp_deploy.yml`.** Per "Org-membership requirement" above, the function resolves `source_repo <- gh_slug_from_remote(path)` (reusing the existing helper from `R/git_utils.R`, already used by `wp_manifest()`) and aborts before opening any PR if it doesn't match `^ofce/` — avoiding a PR a reviewer would just have to reject.
- **`annee`/`wp` collision and auto-numbering both require a fresh `registry.json` fetch** (plain unauthenticated request against `raw.githubusercontent.com`, since the registry is public) — done synchronously inside the function, not cached, since stale data here would either propose a number that's already taken or silently skip a legitimate one.
- **PR creation itself** (branch, commit, push, `gh pr create`) is not sketched in detail here; it follows the same `gh`/`gert`-based pattern already used elsewhere in `ofceweb` (e.g. `R/git_utils.R`, `R/setup_site.R`) rather than introducing a new git-automation approach.
- **`registered-by`** (the registry schema's audit field, distinct from `contact`) is resolved separately from the local GitHub identity — e.g. `gh api user --jq .login` — not from `contact`/`git config`, since a commit's `user.email` need not match the authenticated `gh` account opening the PR.

### Publish-time verification (`ftp_deploy.yml` changes)

Add a step immediately after checkout, before any FTP/staticrypt secrets are used (same position as today's Phase 1 anti-collision step — likely replacing it, see "Relationship to Phase 1" below):

1.  **Org-membership check (new, decided 2026-08-22):** verify `github.repository_owner == 'ofce'`; fail immediately if not — see "Org-membership requirement" above. This runs before secrets are touched and before the registry is even fetched.
2.  Compute `{annee, wp}` for this run (from `manifest.json`/`_quarto.yml`).
3.  Fetch and merge **every** `registry-*.json` shard from `wp-registry`'s default branch (see "Multiple/sharded registry files" above for the shard-enumeration mechanism and why "fetch `registry.json`" elsewhere in this plan now means this merged fetch) — the read itself needs no auth since the registry is public, though enumerating shards may use `GITHUB_TOKEN` (already available for free in the Actions run) rather than an unauthenticated listing call.
4.  Look up the entry for `{annee, wp}` across the merged set:
    - **No entry** → fail with `::error::` — *"WP {annee}/{wp} is not registered in wp-registry. Contact an OFCE web admin to register this repository before publishing."* This is a behavior change from Phase 1, which allowed an unregistered first deploy to pass silently; now every publish, including the first, requires prior registration.
    - **Entry found, `type: "repo"`, `source-repo` matches `github.repository`** → proceed.
    - **Entry found, `type: "repo"`, mismatch** → fail, same message/semantics as today's Phase 1 check, but now unconditional (keying on `{annee, wp}` rather than the live manifest closes the `custom_version` bypass).
    - **Entry found, `type: "pdf-only"`** → fail unconditionally, regardless of caller — *"WP {annee}/{wp} is registered as a PDF-only publication with no associated repository. Publishing a Quarto-based WP under this number is not permitted; contact an OFCE web admin if this needs to change."* This blocks any repo from ever claiming a number that's permanently reserved for a legacy/manual PDF.

### PDF-only / no-repo WPs

Not every WP is produced by a Quarto repo with a `ftp_deploy.yml` — some (mostly older ones, but not exclusively) exist only as a PDF uploaded directly to the FTP tree, with no GitHub repo, no `manifest.json`, and no CI pipeline at all. These fall outside the `ftp_deploy.yml`-driven check entirely, since there is no workflow run to intercept, but they still need to occupy a slot in the registry for two reasons:

1.  **Collision prevention** — without a registry entry, nothing stops a new repo from later registering and publishing a Quarto-based `{annee, wp}` that collides with an already-published PDF-only paper at that same number.
2.  **Completeness** — an admin scanning the registry should be able to tell "this number is taken" for *any* published WP, not just repo-based ones.

Handling:

- Add these as `type: "pdf-only"` entries (`source-repo: null`) via the same admin-reviewed PR process as `type: "repo"` entries — there is no "Option B" automation possible here since there's no repo to run `wp_registry_request()` from; these are always Option A (manual PR), likely batched.
- No `ftp_deploy.yml` changes are needed to *produce* these entries (nothing publishes them through that workflow), only to *respect* them (the lookup step above already handles this by failing closed on `type: "pdf-only"`).
- If a PDF-only WP is ever migrated to a proper Quarto repo later (e.g. a retroactive re-typesetting), that's a deliberate admin action: edit the existing entry's `type` to `"repo"` and set `source-repo` accordingly, rather than creating a second entry for the same `{annee, wp}`.

### Relationship to Phase 1's existing manifest check

Recommend **keeping both** as defense-in-depth: - Registry check → authorizes *who* may publish to `{annee, wp}` at all. - Live-manifest check (existing) → catches the narrower case where the currently-deployed manifest at the *exact target subpath* disagrees with what's expected, even from an already-authorized repo (e.g. stale/partial deploys, manual FTP tampering).

### Relationship to the Phase 2 (Environment) plan

This registry scheme substantially reduces the need for a per-deploy reviewer gate: the human-in-the-loop moment moves from *"before every FTP push"* to *"before a repo is ever authorized to claim a WP number,"* which happens once per WP rather than on every render/republish cycle. It also sidesteps the GitHub plan/visibility limitations that made the Environment approach inconsistent across OFCE's public/private WP repo mix.

**Recommendation:** treat this registry scheme as the primary replacement for Phase 2. Keep the Environment/manual-approval-Action idea from `2026-08-21-1605-plan-wp-publish-security-phase2.md` on file only as an optional additional per-deploy gate, to be revisited if OFCE later decides routine re-publishes of an already-registered WP also need individual review (not just the initial registration).

## Migration / backfill

Already-published WPs need a one-time baseline import into `wp-registry` so they don't get locked out under the new "must be registered" rule. This is an administrative, largely manual task: - Enumerate existing live WPs (from OFCE's FTP tree / existing `manifest.json` files, or an internal list of published working papers) and their known `source-repo` (from Phase 1's manifest field, where present). - Compile into one bulk PR against `wp-registry`, reviewed/merged by an admin as the initial baseline. - Not automatable from `ofceweb` alone since it requires enumerating the live FTP tree outside the package's normal write path — a one-off script or manual compilation is fine here.

**Baseline list compiled (2026-08-22), source of truth: xtimbeau's knowledge of currently-published WPs:**

``` json
{
  "wp": [
    { "annee": 2025, "wp": 23, "source-repo": "xtimbeau/travail", "registered-by": "xtimbeau", "registered-at": "2026-08-22" },
    { "annee": 2026, "wp": 6, "source-repo": "ofce/trec", "registered-by": "xtimbeau", "registered-at": "2026-08-22" },
    { "annee": 2026, "wp": 9, "source-repo": "ofce/site_cahier_BL", "registered-by": "xtimbeau", "registered-at": "2026-08-22" },
    { "annee": 2026, "wp": 10, "source-repo": "ofce/acit", "registered-by": "xtimbeau", "registered-at": "2026-08-22" }
  ]
}
```

Note `xtimbeau/travail` (`2025-23`) sits outside the `ofce` org and any `wp-*` naming pattern — see open decision 7 below on the resulting gap in the Tier 1 workflow-tampering mitigation.

**Separate, larger backfill still needed: PDF-only legacy WPs.** In addition to the 4 repo-based entries above, there is reportedly a long list of older WPs published as bare PDFs with no associated repo (see "PDF-only / no-repo WPs" above for why these still need a registry entry, as `type: "pdf-only"`). This list has **not yet been compiled or sourced** — see open decision 8 below.

### Simplifying `setup_wp()`: `wp`/`annee` resolved via the registry, not user-supplied — proposed 2026-08-22

Today, `setup_wp(wp = ..., annee = ...)` lets the caller pick both values directly, then patches `_quarto.yml` accordingly (`site-path`, `citation.issue`/`citation.url`, `FTP_SERVER_DIR`, etc. — see `R/setup_wp.R` sections 11–12). Once registration is admin-gated through `wp-registry`, letting a user freely choose `wp`/`annee` in `setup_wp()` no longer makes sense — the number isn't really theirs to choose; it's whatever the registry grants. Proposed new flow:

1.  **Drafting is unaffected.** `setup_wp()` called with no `wp` (the existing default) still produces a GitHub Pages pre-publication draft, exactly as today.
2.  **`wp_registry_request()` becomes the sole place `{annee, wp}` is decided.** It resolves the pair one of two ways:
    - **Manual:** the caller passes an explicit desired `wp` (and `annee`, default current year). `wp_registry_request()` still checks the fetched `registry.json` for a collision at that exact `{annee, wp}` before opening the PR, and refuses locally (no PR opened) if already taken.
    - **Automatic:** the caller omits `wp`. `wp_registry_request()` fetches `registry.json`, filters entries by the given (or default current-year) `annee`, and proposes `max(existing wp for that annee) + 1` across **both** `type: "repo"` and `type: "pdf-only"` entries (both consume the same number space).
    - Either way, the PR it opens against `ofceweb/wp-registry` is the same shape as before; only how the proposed `wp` value is derived differs.
3.  **`setup_wp()` no longer accepts a meaningful `wp`/`annee` to *assign*.** Once a repo's registry PR is merged, re-running `setup_wp()` (still with no `wp`/`annee` arguments) should detect the now-published `{annee, wp}` by fetching `registry.json` and matching `source-repo` against the current repo's own remote (reusing the existing `gh_slug_from_remote()` resolution already used for `manifest.json`'s `source-repo` field) — then patch `_quarto.yml` exactly as it does today for an explicitly-supplied `wp`. In effect, `setup_wp()`'s "promote draft → published" behavior becomes driven by *registry state*, not by a user-supplied argument.
4.  **Simplification for `setup_wp()`'s signature/logic:** the `wp`/`annee` parameters likely shrink to an escape hatch for admin/manual overrides (e.g. fixing a repo whose registry lookup fails, or legacy repos migrated before this scheme existed) rather than the primary way of setting them — exact scope of what to keep vs. remove is an open decision below.

**Race-condition note for automatic numbering:** two concurrent `wp_registry_request()` calls for the same `annee` could compute the same "next" number before either PR is merged (the registry only reflects state as of the last merge, not in-flight PRs). Mitigation: add a CI check to `wp-registry` itself (on `pull_request`) that fails the check if merging would produce a duplicate `{annee, wp}` — this makes the *human reviewer* the actual collision-resolution point (reject/ask-to-rerun the second PR), consistent with the registry's overall "admin merge = authorization" model, rather than trying to solve the race client-side.

### Staging = GitHub Pages, publish = FTP after registry confirmation — resolved 2026-08-23

**All not-yet-published WPs are "staged," and staging is hosted entirely on GitHub Pages** — the same mechanism `setup_wp()` already uses for its plain `wp = NULL` draft preview. There is no separate FTP-based staging path; the earlier `stage/{repo-name}/` FTP design (and everything built on it — retention periods, a cleanup cron job, FTP directory-listing) is **dropped**. This resolves the "supplement vs. replace" question left open by the 2026-08-22 reconsideration: GitHub Pages staging **replaces** the FTP-staging design outright.

Consequences, replacing the corresponding earlier (now superseded) decisions:

- **No `ofce`-org-membership gate for staging.** GitHub Pages needs no FTP/staticrypt secrets, so a repo outside `ofce` can still get a staged preview — the org-membership check (see "Org-membership requirement" above) only ever gates the *numbered FTP publish* path, where the actual secrets are used. (A non-`ofce` repo can preview a draft indefinitely, but can never be registered/published while outside `ofce`.)
- **Encryption is optional, not mandatory.** Staticrypt on staged GitHub Pages output is available to a repo that wants it (reusing the existing opt-in `STATICRYPT_PASSWORD` secret mechanism), but is no longer required by default. This reverses the earlier "encrypted by default" decision, which was motivated by FTP-hosted staging being harder to keep private; that rationale no longer applies once nothing is pushed to FTP pre-registration.
- **Draft and staged collapse into one mechanism, not two.** Both are the same GitHub Pages output at the same URL (`https://{gh_org}.github.io/{repo}/`); the only difference is banner wording depending on whether local intent (`wp`/`annee` set) plus registry state indicates "not yet requested" vs. "requested, pending admin approval" vs. (once merged) "published." See "Template changes" and "Exact staging-flag mechanism" below for how that's surfaced.
- **"Published" is defined purely by registry state.** A repo is published if and only if a `type: "repo"` entry in `registry.json` matches its `source-repo` — there is no separate notion of "PR merged but not yet republished" to design around. The very next render/publish cycle after merge fetches the registry, finds the match, and switches the repo from staged to published.
- **Cleanup is trivial and needs no new design.** Since staged output only ever lives on the GitHub Pages branch (already garbage-collected/overwritten by ordinary re-renders, same as today's draft mode), there's nothing analogous to the FTP staging folder that needs scheduled deletion.
- **Known caveat carried over unchanged:** GitHub Pages sites are publicly visible once built, for both public and private repos, unless the org is on GitHub Enterprise Cloud (OFCE is on Team). This is an already-accepted tradeoff for today's plain draft mode and now applies identically to all staged (pre-registration) WPs; a repo with especially sensitive draft content should opt into staticrypt.

### Template changes: visible "staging / not yet published" marker — raised 2026-08-22

Staged output should visibly announce itself as a pre-publication draft, not a real numbered OFCE working paper — across all three output formats (`wp-html`, `wp-pdf`, `wp-typst`), e.g. a banner/watermark such as "Version provisoire — non publiée" shown whenever the content is being deployed to the staging path rather than the numbered one.

**Important scoping note:** the actual format templates (`wp-html`/`wp-pdf`/`wp-typst`) are **not** part of `ofceweb` — they live in the separate `OFCE/ofce-quarto-extensions` repo, installed into each WP repo via `ofce::setup_quarto()` (see `setup_wp()` step 9). So this isn't an `ofceweb`-only change: it needs a corresponding update in `ofce-quarto-extensions` to add a conditional banner/watermark partial to each format, consuming the metadata flag defined in "Exact staging-flag mechanism" below. Needs its own design pass in that repo once the staging mechanism is finalized; flagged here as a cross-repo dependency, not forgotten.

### Exact staging-flag mechanism — resolved design 2026-08-22

**Architecture correction found while designing this:** `ftp_deploy.yml` (the workflow that carries today's Phase 1 anti-collision check, and where the registry lookup was originally slotted in this plan) does **not itself render anything** — it checks out already-rendered static output from the `site-deploy` branch and uploads it via FTP. There is no `quarto render` step in that workflow at all. Actual rendering happens earlier, either locally via `render_wp()` or in CI via `render_and_deploy.yml`'s `Rscript -e "ofceweb::render_wp(...)"` step. **This means a banner baked into the HTML/PDF/Typst output itself must be decided at render time, not inside `ftp_deploy.yml`** — by the time `ftp_deploy.yml` runs, the files are already static. (Related, independent finding: `render_and_deploy.yml` — the direct render+deploy path — currently has **no anti-collision/registry check at all**, unlike `ftp_deploy.yml`; worth fixing regardless of the staging question, since today it can silently overwrite another repo's live WP.)

Proposed mechanism, keeping one single source of truth for both the baked-in banner and the eventual publish decision, updated 2026-08-23 for the GitHub-Pages-staging design above (this removes the earlier FTP-staging-path drift-risk analysis entirely, since `ftp_deploy.yml` is now only ever invoked for a confirmed, registered publish — there's no second, independently-triggered workflow writing to a staging path that could drift out of sync):

1.  **`render_wp()` performs the registry check itself**, before calling `quarto::quarto_render()`: fetch `registry.json`, resolve this repo's `source-repo` (reusing the existing `gh_slug_from_remote()` helper already used for `manifest.json`), and look for a matching `type: "repo"` entry. **`{annee, wp}` are taken from that matched entry, not from local `_quarto.yml`** — this is the concrete mechanism behind "number of the wp is taken from the registry" and finalizes decisions 10/11 below. Result: a boolean `stage <- TRUE`/`FALSE` (no match → `TRUE`, no `annee`/`wp` assigned, GitHub Pages is the only output target; confirmed match → `FALSE`, `annee`/`wp` set from the registry entry, output also targets the numbered FTP path). This also closes the `render_and_deploy.yml` gap noted above, since the check now lives in the shared R function both workflows call.
2.  **Pass `stage` into the render as Quarto metadata:** `quarto::quarto_render(output_format = "all", metadata = list(stage = stage))` (the `quarto` R package's `quarto_render()` accepts a `metadata` list merged into the project metadata for that render). `ofce-quarto-extensions`'s format templates read `{{< meta stage >}}` (or a Lua filter reading `meta.stage`) to conditionally show the banner/watermark in each of `wp-html`/`wp-pdf`/`wp-typst` — this is the concrete hook the "Template changes" section above needs.
3.  **Persist `stage`, `annee`, and `wp` in `manifest.json`** (extend `wp_manifest()`'s schema with a `"stage": true/false` field, alongside `annee`/`wp` now always sourced from the registry match rather than local config). Since `ftp_deploy.yml` is only triggered/meaningful for the `stage == FALSE` case (there's nothing to numerically publish otherwise), this manifest value is informational/traceable rather than a second authorization path.
4.  **`ftp_deploy.yml` still performs its own fresh registry check at deploy time** (per "Publish-time verification" above) — org-membership check, then registry match — immediately before using the FTP secrets. It does not trust the manifest's `stage`/`annee`/`wp` values for authorization; if the fresh check no longer confirms a match (entry removed, repo deregistered, etc. since the last render), it aborts rather than publishing. This keeps the registry check as the sole live authority for the numbered path, without needing a staging-path fallback to reason about.

## New/changed `ofceweb` pieces (once decisions below are made)

- `ftp_deploy.yml` template: replace (or augment) the Phase 1 anti-collision step with the registry-lookup step described above.
- `setup_wp()`: idempotent migration logic (parallel to the existing `FTP_SERVER_DIR`/anti-collision migrations) to inject the registry check into a pre-existing `ftp_deploy.yml` that lacks it.
- **Shared shard-fetch/merge helper (new, added 2026-08-23):** since every consumer (`ftp_deploy.yml`, `render_wp()`, `wp_registry_request()`) needs the same "enumerate `registry-*.json` shards, fetch each, merge into one entry list" logic (see "Multiple/sharded registry files" above), this should be a single internal R helper (e.g. `wp_registry_fetch()`) called from all three places rather than duplicated per call site — the GitHub Actions steps in `ftp_deploy.yml` would invoke it via `Rscript`, consistent with how other checks in that workflow already shell out to `ofceweb`.
- `wp_registry_request()` (decided above): new exported function, computes `{annee, wp, source-repo}` from local `_quarto.yml`/`manifest.json` and opens a PR against `ofceweb/wp-registry` via `gh`/`gert`. Takes a `contact` parameter (**resolved 2026-08-23**: defaults to the local `git config user.email`, overridable by passing an explicit value). Consider invoking it from `setup_wp()` interactively as well as standalone.
- Optional `wp_registry_check()` (R-level pre-flight check, so a contributor can verify registration locally before pushing) — nice-to-have, not required for the decided design.
- New tests covering: registered match passes, unregistered fails, mismatched `source-repo` fails, `pdf-only` match always fails, and `wp_registry_request()`'s PR-creation logic against a mocked registry repo.
- `wp-registry` itself needs a `README.md` documenting the schema, how to request a number, and admin review responsibilities — this lives in the new repo, not in `ofceweb`.
- `NEWS.md` entry once implemented.

## Open decisions (need user/admin input before implementing)

1.  ~~Registry repo name and location (`ofce/wp-registry` assumed above) and final visibility choice.~~ **Resolved 2026-08-22:** the registry repo will live in the **`ofceweb` organisation** (not `ofce`) and be **public**. All references to `ofce/wp-registry` elsewhere in this plan should be read as `ofceweb/wp-registry` (or whatever exact name is chosen within that org — the name itself is still a minor detail to finalize, but the org and visibility are now fixed).
2.  ~~Registration workflow: manual PRs only (A), or build the `wp_registry_request()` automation (B)?~~ **Resolved 2026-08-22: Option B (automated).** Build `wp_registry_request()` to compute `{annee, wp, source-repo}` from the local `_quarto.yml`/`manifest.json` and open the PR against `ofceweb/wp-registry` automatically (via `gh`/`gert`). The human merge/review gate is unchanged — this only removes manual JSON editing. (This only applies to `type: "repo"` entries; `type: "pdf-only"` entries still require a manual PR, since there's no local repo/`_quarto.yml` to compute from — see "PDF-only / no-repo WPs" above.)
3.  Keep Phase 1's live-manifest check alongside the new registry check, or retire it once the registry is authoritative?
4.  ~~Who sits on the `wp-admins` CODEOWNERS/reviewer team for `wp-registry`?~~ **Resolved 2026-08-23 (provisional): xtimbeau, for now.** A single-admin arrangement is acceptable to start; revisit if/when a broader `wp-admins`/`web-admins` team is formalized. **Implemented 2026-08-23:** `.github/CODEOWNERS` added to `ofceweb/wp-registry` (`@xtimbeau` on `*` and `/registry.json`), and `require_code_owner_reviews` enabled on the `main` branch protection rule — a PR touching `registry.json` now requires xtimbeau's approval to merge. `enforce_admins` deliberately left `false` for now (single-admin setup). Note re: sharding (added 2026-08-23, see "Multiple/sharded registry files" below) — the existing `*` (whole-repo) CODEOWNERS line already covers any future `registry-*.json` shard file with no update needed; the more specific `/registry.json` line only matters for today's single file and can be broadened to `/registry-*.json` (or dropped, since `*` already covers it) once sharding is actually implemented.
5.  ~~Who performs the one-time migration/backfill of already-published WPs, and what's the source of truth for that initial list?~~ **Resolved 2026-08-22:** xtimbeau compiled the list from memory (4 entries: 2025-23, 2026-6, 2026-9, 2026-10); see baseline JSON under "Migration / backfill" above.
6.  ~~Confirm current GitHub docs on branch-protection/required-PR-review availability across plans/visibility.~~ **Resolved 2026-08-22:** re-checked against current GitHub docs. Two distinct mechanisms, two distinct plan gates:
    - **Repo-level** branch protection / repository rulesets are available on **GitHub Free** (personal or org) **for public repositories only**; private repos need Pro/Team/Enterprise. Since `wp-registry` itself is public, this is sufficient to require PR review on `registry.json` via ordinary repo-level branch protection or a repo-scoped ruleset + `CODEOWNERS` — no plan upgrade needed for the registry repo's own governance.
    - **Organization-level** rulesets (the mechanism Tier 1 below relies on, to stop a WP repo's own admin from editing that repo's `ftp_deploy.yml`) require **GitHub Team or Enterprise** — extended to Team plans in mid-2025, but still **not available on GitHub Free at any visibility**, public or private. This directly affects decision 7 below.
7.  **Org-targeting for the Tier 1 org-level ruleset — resolved 2026-08-22, given `ofceweb` is a free (Free-plan) org, and further tightened by the org-membership policy decided the same day (see new "Org-membership requirement" section below).**
    - An organization-level ruleset can only target repos *within the org it's created in*. Since WP source repos are now **required** to live under **`ofce`** (Team plan), the Tier 1 ruleset is created **inside the `ofce` org**, not `ofceweb` — the registry's own org and the WP-repos' org are intentionally different, and the ruleset belongs with the latter. `ofceweb` hosting the registry doesn't need an org-level ruleset at all for that purpose.
    - Because `ofceweb` is on **GitHub Free**, it **cannot host an org-level ruleset even if it wanted to** — only repo-level rulesets/branch protection (fine, since `wp-registry` is public — see decision 6). This is now moot for WP source repos, since the org-membership policy forbids hosting them under `ofceweb` anyway; it would only matter if `ofceweb` itself grew unrelated repos needing similar protection, which is out of scope here.
    - ~~The naming-convention gap for personal-account/off-org repos (e.g. `xtimbeau/travail`).~~ **Resolved 2026-08-22 by policy, see "Org-membership requirement" below:** such repos are no longer a tolerated edge case — they're disallowed outright. `xtimbeau/travail` must be **transferred into `ofce`** before it can be (re-)registered; see decision 9.
8.  **Source and scope of the PDF-only legacy backfill.** A long list of older WPs published as PDF-only (no repo) reportedly exists and needs `type: "pdf-only"` registry entries (see "PDF-only / no-repo WPs" above), but the list itself hasn't been compiled yet. Candidate sources: OFCE's live FTP directory tree (enumerate `{annee}/{wp}` folders that contain a PDF but no `manifest.json`), the public WP listing/search index on ofce.fr, or an internal spreadsheet if one already exists. Needs a decision on (a) which source is authoritative, (b) whether enumeration can be scripted (e.g. against the FTP tree or a site index) or must be compiled by hand, and (c) who does it.
9.  ~~New, from the `ofce`-only org-membership policy: `xtimbeau/travail` (`2025-23`) must be transferred into `ofce` before it can be registered.~~ **In progress 2026-08-22:** xtimbeau will handle the `xtimbeau/travail` → `ofce` transfer directly. Until the transfer completes, this WP cannot pass the new org-membership check in `ftp_deploy.yml` and cannot be republished/updated under this scheme; the baseline registry entry recorded under "Migration / backfill" above should be updated to `"source-repo": "ofce/travail"` (or whatever name it retains) once the transfer is done.
10. ~~`setup_wp()` simplification — does `wp`/`annee` disappear from the signature entirely, or remain as a manual-override escape hatch?~~ **Resolved 2026-08-22: they disappear from `setup_wp()`'s argument list entirely.** `wp`/`annee` are no longer arguments a caller sets directly on `setup_wp()`; the only route to setting them is via `wp_registry_request()` (or, for `pdf-only` entries, a manual registry PR that a later `setup_wp()` run then picks up — see decision 11).
11. ~~How does `setup_wp()` "detect from registry" interact with offline use / fetch failures?~~ **Resolved 2026-08-22:** `_quarto.yml` keeps storing `wp`/`annee` locally, as today. `setup_wp()` still reads/writes them from the local YAML as its baseline (so it works fully offline), but that local value is now understood as a **cached/candidate** value, not an authorization. **The registry fetch + match becomes mandatory specifically at publish time** (i.e., inside `ftp_deploy.yml`'s existing lookup step, not inside `setup_wp()` itself) — so a missing network connection when running `setup_wp()` locally is a non-issue, but a CI run that can't verify the registry (or finds no match) must not silently publish to the numbered path. See new open item 13 below for exactly what it should do instead of a hard failure.
12. ~~Should `wp_registry_request()` block until merged, or fire-and-forget?~~ **Resolved 2026-08-22: fire-and-forget.** It opens the PR and returns; the user is told to re-run `setup_wp()` (or wait for CI to pick it up automatically — TBD) once the PR is merged. No polling/blocking mode.
13. ~~New, raised 2026-08-22: unregistered/pending WPs should still be publishable to FTP in a "staged" form, not just hard-fail.~~ **Resolved 2026-08-23: staging is not FTP-based at all — see "Staging = GitHub Pages, publish = FTP after registry confirmation" above.** Unregistered/pending WPs are staged on GitHub Pages (no FTP secrets, no org-membership gate, optional encryption); the numbered FTP path opens up only once a `type: "repo"` registry entry confirms the match. This also answers the questions this item originally raised: staging path (moot — GitHub Pages URL, not an FTP path), org-membership gate (not required for staging), promotion (automatic on next render/publish after registry merge), and stale-content cleanup (moot — no FTP staging folder is ever created).
14. **New, raised 2026-08-23: shard-enumeration mechanism for the multi-file registry.** Now that the registry may be split across several `registry-{id}.json` files (see "Multiple/sharded registry files" above), every consumer needs a way to discover the current full set of shard files before treating a lookup/collision-check as complete. Two candidates are sketched there — (1) GitHub Contents API listing, using `GITHUB_TOKEN`/authenticated `gh` (already available in both consumer contexts, so no new secret is needed) to avoid the tighter anonymous rate limit, vs. (2) a maintained `registry-index.json` fetched via plain `curl`, at the cost of a second file that must be kept in sync. Leaning towards (1); needs a final decision before `ftp_deploy.yml`/`wp_registry_request()`/`render_wp()` implementation.

## Defense against workflow tampering

The registry check only helps if it actually runs unmodified. Anyone with write access to a WP repo can edit that repo's own `ftp_deploy.yml` — GitHub does not otherwise prevent repo maintainers from editing their own workflow files. Two tiers of mitigation, in increasing order of effort:

### Tier 1 — require admin review to change the workflow (recommended default)

**Important correction:** ordinary repo-level branch protection is not sufficient on its own. Configuring/editing branch protection requires admin access to *that* repo, and WP repo authors are commonly also the repo's admin — so a repo-level rule and the person it's meant to constrain share the same trust boundary; that admin could simply loosen or delete the rule.

The fix is to use an **organization-level ruleset** instead of (or in addition to) repo-level branch protection:

- **This ruleset must be created inside the `ofce` organization** (where the WP source repos actually live, and which is on GitHub Team), **not `ofceweb`** (which hosts the registry and is on GitHub Free — see open decisions 6/7 above for why `ofceweb`, being Free, couldn't host an org-level ruleset at all even if it wanted to). An **`ofce` org owner** (not a WP repo's own admin) creates one organization-level ruleset targeting all WP repos (e.g. by a `wp-*` name pattern), requiring PRs and a `CODEOWNERS`-based admin-team review for changes to `.github/workflows/**`.
- If a repository is targeted by an organization-level ruleset, only organization owners can edit that ruleset — a WP repo's own admin can add *additional* repo-level rulesets on top, but cannot weaken or remove the org-level one; the two aggregate, with the most restrictive version of any overlapping rule applying.
- Bypass is opt-in and org-owner-controlled: repository-admin status does **not** automatically grant bypass of an org-level ruleset unless the org owner explicitly adds that role to the ruleset's bypass list — leave it off for `wp-*` repos.
- **Plan availability:** this required GitHub Enterprise until recently, but organization rulesets can now be targeted and enforced at the organization level for GitHub Team plan customers as of mid-2025 — so this works on `ofce`'s existing Team subscription, but would **not** work if these WP repos instead lived under `ofceweb` (Free) or a personal account, per open decision 7.
- Combine with the Environment's **"Deployment branches and tags"** restriction (works on private repos on GitHub Team, unlike required reviewers) set to the protected branch only, so a `workflow_dispatch` run from a scratch/unmerged branch with a tampered workflow still can't obtain the FTP secrets.
- Net effect: bypassing the check requires either an org owner's own cooperation, or getting a malicious diff past a required admin reviewer — the same trust boundary already relied on for `wp-registry` itself. No new infrastructure needed beyond the one org-level ruleset.

#### Draft implementation artifacts

**Organization ruleset**, created via `POST /orgs/{org}/rulesets` (or the equivalent `gh api`/Terraform call) by an org owner. Targets every repo matching a `wp-*` naming convention (adjust the pattern to OFCE's actual convention) and enforces PR-based changes with required `CODEOWNERS` review on the default branch:

``` json
{
  "name": "wp-repos-workflow-protection",
  "target": "branch",
  "source_type": "Organization",
  "enforcement": "active",

  "conditions": {
    "repository_name": {
      "include": ["wp-*"],
      "exclude": []
    },
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },

  "bypass_actors": [
    {
      "actor_type": "Team",
      "actor_id": "<id of ofce web-admins team>",
      "bypass_mode": "pull_request"
    }
  ],

  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    }
  ]
}
```

Notes: - `bypass_actors` deliberately omits `RepositoryAdmin` — including it would re-open the exact loophole this ruleset exists to close. The single team entry (with `bypass_mode: "pull_request"`) is an optional break-glass path that still requires a PR, just skips the required-review count; omit it entirely if no such escape hatch is wanted. - `require_code_owner_review: true` enforces admin sign-off on `.github/workflows/**` specifically only in combination with the `CODEOWNERS` entry below — the ruleset itself doesn't know about paths; `CODEOWNERS` is what maps that directory to the admin team. - **Unverified against live docs:** whether the newer path-scoped "required review from a specific team for changes to specific files/directories" capability is exposed as its own rule type or as additional `pull_request` parameters in the current ruleset API, and the exact `actor_type`/`actor_id` shape for a `Team` bypass entry. Both should be dry-run against a test ruleset (or checked in current GitHub API docs) before rollout; the `CODEOWNERS`-based approach above avoids depending on either being confirmed, since its schema is stable and well-documented.

**`CODEOWNERS`**, added to each WP repo (candidate for `setup_wp()` to scaffold automatically):

```         
# .github/CODEOWNERS
/.github/workflows/  @ofce/web-admins
```

This routes review of any change under `.github/workflows/` (including `ftp_deploy.yml`) to the `@ofce/web-admins` team, while leaving other files free to be approved by whichever reviewers a repo's own norms call for.

### Tier 2 — never expose FTP credentials to the WP repo at all (stronger, more effort)

- Store FTP/staticrypt secrets as **organization secrets scoped to "Selected repositories" = a new admin-only repo** (e.g. `ofce/wp-deploy`), not the individual WP repos, so no edit to a WP repo's own YAML can ever reach the secret.
- WP repos only render the site and publish a build artifact/deploy branch; the actual FTP push and registry check run entirely inside `ofce/wp-deploy`'s own (admin-only-editable) workflow.
- Triggering `ofce/wp-deploy` from a WP repo (`repository_dispatch` or similar) cannot rely on a self-reported payload for identity (a tampered caller workflow could lie about which repo/version it represents). Instead, `ofce/wp-deploy`'s workflow must independently query the GitHub API for the actual triggering repository/branch/commit and read `manifest.json` from that verified location itself before checking it against `wp-registry`.
- More infrastructure (a second repo, a trigger/hand-off mechanism) — treat as an escalation path if Tier 1 is ever judged insufficient, not a day-one requirement.

**Recommendation:** start with Tier 1; it's proportionate to an internal contributor threat model and reuses infrastructure already implied by the registry's own governance. Revisit Tier 2 only if a stronger threat model (e.g. untrusted external contributors) becomes relevant.

## Non-goals for this phase

- No changes to `check_wp()` (citation validation was explicitly declined in an earlier session; unrelated to this plan).
- Not attempting to unify GitHub Environments across repos at the org level — confirmed not possible on GitHub's current model (see Phase 2 plan).
- Does not by itself add per-deploy human review for already-registered repos' routine republishes (see "Relationship to Phase 2" above).
