------------------------------------------------------------------------

editor_options: markdown: wrap: 72 ---

# Plan: Align `manifest.json` with data model v1 (`modele-donnees-v1.qmd`)

Status: **implemented in ofceweb 1.0.5 (2026-10-23)** — generators (`R/wp_manifest.R`, `R/pb_manifest.R`, shared helpers in `R/manifest_v1.R`), templates, tests, roxygen, NEWS and both spec docs done. Remaining: rollout (§5) — regenerate the 7 registered WPs via `render_wp()` + deploy. Proposed 2026-10-22 following the audit of the same day; all open questions (Q1–Q4) settled 2026-10-22.

Reference docs: `../webdocs/modele-donnees-v1.qmd` (condensed reference) and `../webdocs/architecture-base-contenus.qmd` §3.1 (full spec). Per the update rule stated in `modele-donnees-v1.qmd` §1, every schema change below must be reflected in **both** documents.

## Audit summary (2026-10-22)

`wp_manifest()` (`R/wp_manifest.R`) and `pb_manifest()` (`R/pb_manifest.R`) produce the pre-v1 schema. All 6 local WP `manifest.json` files checked (wp-xt-travail, wp-gamp-gainemploi, wp-gaxt-acit, wp-gaxt-trec, wp-hp-parenthood, wp-pam-pmq) fail identically:

- **Missing required fields** (11 of 15): `schema_version`, `id`, `translation_id`, `institution`, `type`, `media`, `categories`, `keywords`, `jel`, `date_published`, `auto_update`.
- **Renamed**: `date` → `date_published`.
- **`authors`**: list of objects `{name, affiliation, orcid}` vs v1 list of strings (spec §3.3 matching assumes strings).
- **`pdf`**: bare filename (`"OFCEWP2026-10.pdf"`) vs v1 absolute URL.
- **`title` empty in 2/6 manifests** (wp-xt-travail, wp-gamp-gainemploi): bug — the title lives in `index.qmd` frontmatter, the manifest reads only `_quarto.yml$title` (unlike `abstract`, which has the fallback).
- **Extra fields outside v1**: `wp`, `annee`, `version`, `stage`, `source-repo`, `pdf-path`, `ofceweb-version` — all with live consumers: `deploy_wp()`/`deploy_pb()` read `manifest$stage`/`$wp`/`$annee`/`$pb`; `ftp_deploy.yml` reads `source-repo` for the anti-collision check (case- insensitive comparison, NEWS 1.0.4).

Registry scope: 7 `type: repo` WP entries (1×2024, 2×2025, 4×2026); PB has 18 entries, all `pdf-only` (no PB repo pipeline in production yet). Previsions produce no manifest at all (out of scope here; §7.6/§6.4 of the source doc).

## Decisions (proposed defaults — to confirm before implementation)

| \# | Decision | Proposal |
|----|----|----|
| D1 | `authors` shape | **Flatten to list of strings** (names as published). Spec §3.3 matching (`authors.yml` aliases) assumes strings. `affiliation`/`orcid` stay in `_quarto.yml` for rendering; nothing is lost. |
| D2 | Legacy fields | **Keep** `wp`, `annee`, `version`, `stage`, `source-repo`, `pdf-path`, `ofceweb-version` alongside v1 fields. Dropping them would require touching `deploy_wp()`/`deploy_pb()` + reinstalling workflows in every repo. The future JSON Schema (Lot 2) must allow additional properties. |
| D3 | `institution` enum | **Decided 2026-10-22 (Q1): keep the v1 spec enum `ofce`/`cepii`/`ife` — no extension.** Template ships `institution: ofce`; generator reads `yml$institution` only (**not** `institut`), defaults to `"ofce"` when absent; unknown value → warning + `"ofce"` (never blocks a deploy). Joint branding stays on the existing `institut` field (Typst logos), untouched — see §2.2. No spec amendment needed for the enum. |
| D4 | `id` format | **Decided 2026-10-22 (Q2, Q3, Q4):** `{institution}-wp-{annee}-{wp}-{lang}` (WP) / `{institution}-pb-{pb}-{lang}` (PB — **no year**, PBs are numbered sequentially), with the `institution` segment taking the simple enum value (`ofce`/`cepii`/`ife`) — **no zero-padding** (matches real URLs `/wp/2026/6/`), short type token `wp`/`pb` as in the spec's own example. Stable across version bumps (`v0`→`v1` must not change it). `null` while the content is a draft without a registered number. Both spec docs' `006` example, the `{type}`-wording and the PB exception must be corrected (§4). |
| D5 | `translation_id` | `null` by default. Reserve an optional `_quarto.yml` field `translation_id`; no pairing mechanism exists yet (wp-gaxt-acit/en ↔ wp-gaxt-trec/fr are translations of each other but nothing records it). |
| D6 | `media` | Constant `"html"` for WP/PB (HTML-first with PDF companion; the PDF URL is carried by `pdf`). |
| D7 | `auto_update` | Constant `true` (aggregator re-checks manifest on every deploy). Becomes a YAML field only if a content ever needs `false`. |
| D8 | Staging/draft manifests | Not v1-conformant **by design**: v1 applies to *published* contents. `id`/`date_published` etc. are still emitted when computable; the collector never sees staging manifests. |

## 1. Manifest generators: `wp_manifest()` / `pb_manifest()`

### 1.1 v1 fields added or renamed

- `schema_version = "1.0"`.
- `id` per D4 — `{institution}-wp-{annee}-{wp}-{lang}` / `{institution}-pb-{pb}-{lang}` (no year for PB, Q4), no zero-padding (Q3); `null` while `wp`/`pb` unknown (draft).
- `translation_id` per D5.
- `institution`: `yml$institution %||% "ofce"`. Enum `ofce`/`cepii`/`ife` (D3). The `institut` field is **not** read — it is a Typst branding field (§2.2), not content ownership; a jointly-branded repo without `institution` gets `"ofce"`. Unknown value → warning + `"ofce"` rather than aborting (metadata errors must not block a deploy).
- `type = "working-paper"` / `"policy-brief"`; `media = "html"` (D6); `auto_update = TRUE` (D7).
- `categories`, `keywords`, `jel`: read from `_quarto.yml`, fallback `index.qmd` frontmatter (same pattern as `abstract`), default `[]`. Coerce scalars to length-1 lists; upper-case `jel` codes (spec: "codes JEL en majuscules").
- `date` → `date_published` in the manifest. YAML key `date` unchanged. `date_modified` unchanged (already conformant).
- `pdf`: absolute URL `https://www.ofce.fr/{pdf-path}` when `pdf-path` is known; `null` otherwise (drafts — the bare filename is no longer emitted, it is useless without the path; behavior change to note in NEWS).
- **Title bug fix**: `title <- yml$title`; if empty/absent, fall back to `index.qmd`'s `title` (same pattern as `abstract`). Non-empty per v1.
- `authors`: emit `list` of `name` strings, order preserved (D1).

### 1.2 Unchanged

Legacy fields per D2; URL computation; `source-repo`; abstract resolution; the `_site/` copy step; JSON writing conventions (`auto_unbox = TRUE`, `null = "null"` — see AGENTS.md).

## 2. Template changes (`inst/setup_wp/`, `inst/setup_pb/`) — user-requested

### 2.1 New fields in `_quarto.yml` (both WP and PB)

Add to the "champs obligatoires" header block:

``` yaml
# Institution porteuse du contenu, lue par wp_manifest()/pb_manifest()
# pour le champ `institution` du manifeste (modèle de données v1).
# Valeurs : ofce (défaut si absent), cepii, ife.
# Pour le logo / co-branding des gabarits Typst (ife, ife-ofce, ife-cepii,
# ife-ofce-cepii), utiliser le champ séparé `institut` (ofce-quarto-extensions).
institution: ofce

# Métadonnées éditoriales (modèle de données v1) : listes, vides si aucune.
# categories : classification éditoriale libre ; keywords : mots-clés libres ;
# jel : codes JEL en majuscules (ex. [E24, E25]).
categories: []
keywords: []
jel: []
```

Rationale for keywords/jel/categories in templates: v1 makes them **obligatory lists** (may be empty). Shipping them as visible empty slots in the template is what makes authors fill them; old repos stay valid via the `[]` fallback in the generator (zero-edit migration).

`institution: ofce` is shipped explicitly (self-documenting); the generator fallback covers old repos that never set it.

### 2.2 Relationship with the existing `institut` field (French spelling)

Two separate fields with separate concerns (settled with Q1, 2026-10-22):

- `institution` — **new, v1 manifest field**: content ownership, enum `ofce`/`cepii`/`ife`, read by `wp_manifest()`/`pb_manifest()` only.
- `institut` — **existing, Typst branding field**: logo selection in `ofce-quarto-extensions` (`_extensions/wp/typst/typst-template.typ`, `instituts` table), 5 values: `ofce`, `ife`, `ife-ofce`, `ife-cepii`, `ife-ofce-cepii`. Untouched by this plan; wp-xt-travail carries `institut: ife-ofce` and keeps rendering as before.

The generators do **not** read `institut`: joint branding is presentation, not ownership — an IFE\|OFCE-branded WP gets `institution: "ofce"` unless the author explicitly sets otherwise. The template comment cross-references `institut` for logos (§2.1).

- Long term: the extensions could also read `institution` and drop the `institut` alias — separate repo (`ofce-quarto-extensions`), separate change, noted here for tracking only.

### 2.3 `index.qmd`

No template change needed (title/abstract already there; the three list fields live in `_quarto.yml`). Manifest reads them from `_quarto.yml` first, `index.qmd` frontmatter as fallback (same precedence as `abstract`).

### 2.4 Existing repos

Templates are only installed by `setup_wp()`/`setup_pb()` for **new** repos. Existing repos (7 registered WPs) need no YAML edit: fallbacks produce valid v1 manifests (`institution: "ofce"`, `[]` lists). The fields become meaningful as authors add them.

## 3. Tests

Update `tests/testthat/test-wp_manifest.R` / `test-pb_manifest.R`:

1.  Existing expectations (`source-repo`, `pdf-path`, staging URL) unchanged — they pin D2 behavior.
2.  New: `schema_version`, `type`, `media`, `auto_update` constants; `id` format + stability across a simulated `version` bump; `id = null` for drafts.
3.  `institution`: explicit `ofce`/`cepii`/`ife` passthrough; default `ofce` when absent; unknown value → warning + `ofce`; `institut: ife-ofce` alone is **not** read (result `ofce`, no warning) — pins the §2.2 separation.
4.  `categories`/`keywords`/`jel`: default `[]`; read from `_quarto.yml`; `index.qmd` fallback; scalar coercion; `jel` upper-casing.
5.  `date_published` present and `date` absent; `pdf` absolute URL when `pdf-path` known, `null` for drafts.
6.  `authors` flattened to strings (order preserved).
7.  Regression: empty `_quarto.yml$title` + title in `index.qmd` → manifest title taken from `index.qmd` (the wp-xt-travail / wp-gamp-gainemploi bug).
8.  Mirror subset for `pb_manifest()` (no `annee`; `pb` sequential).

`helper-repo-fixtures.R` fixtures need no change (fallbacks cover them), but one fixture should gain the new fields to test passthrough.

## 4. Documentation updates (required by the spec's own update rule)

- `modele-donnees-v1.qmd`: **no enum change** (Q1 keeps `ofce`/`cepii`/`ife` as written). Correct the `id` convention per Q2–Q4: prefix = `institution` value, **no zero-padding** (example becomes `ofce-wp-2026-6-fr`), short type token `wp`/`pb`, and the **PB exception — no year segment** (`ofce-pb-153-fr`); both the stated convention (`{type}` = `working-paper`, `{annee}` for all) and the `006` example need fixing; add a schema-history row (October 2026, implementation of v1 by `wp_manifest()`/`pb_manifest()`).
- `architecture-base-contenus.qmd`: same §3.1 `id` corrections; update §7.1 addendum once implemented (mark the WP gap as resolved, keep the PB gap note until a PB repo pipeline exists).
- Roxygen headers of `wp_manifest()`/`pb_manifest()`: document the v1 fields and the template fields.
- `NEWS.md` entry (1.0.5): manifest v1 alignment, `institution` template field, title fallback fix, `pdf` absolute URL (behavior change for drafts).

## 5. Rollout / migration

1.  Implement + test in ofceweb; bump version.
2.  Regenerate manifests in the 7 registered repo-type WPs via `render_wp()` + deploy (manifest rides along with `_site/`, and the `ftp_deploy.yml` anti-collision step re-reads it — no workflow change needed since `source-repo` is kept per D2).
3.  Old manifests on the FTP are replaced on next deploy of each repo; there is no collector in production yet (§7.2), so no transition period to manage — repos can migrate at their own pace.
4.  PB repos: same code path, exercised when the first PB repo pipeline goes live.
5.  Out of scope, tracked elsewhere (§7.6 of the source doc): `pdfs` repo / `pdf-only` registry entries; previsions/nowcast manifests; the `contentdb` declaration mechanism.

## Open questions (answer before or during implementation)

- **Q1 — enum completeness — ANSWERED 2026-10-22**: keep the spec enum `ofce`/`cepii`/`ife`. Joint-branding values stay on `institut` (§2.2). No spec amendment needed for the enum.
- **Q2 — `id` prefix — ANSWERED 2026-10-22**: the institution segment of the `id` takes the simple enum value (`ofce`/`cepii`/`ife`), e.g. `ofce-wp-2026-23-fr` — no joint-branding expansion in the id.
- **Q3 — zero-padding + type token — ANSWERED 2026-10-22**: **no zero-padding** — `ofce-wp-2026-6-fr`, matching real URLs `/wp/2026/6/`. Type token: short form `wp`/`pb`, as in the spec's own example (only the stated convention wording, `{type}` = `working-paper`, diverges). Both spec docs must state it (§4).
- **Q4 — PB `id` without year — ANSWERED 2026-10-22**: confirmed — **no year segment in the PB id**: `{institution}-pb-{pb}-{lang}` (e.g. `ofce-pb-153-fr`), consistent with sequential PB numbering. Spec docs must state the PB exception to the `{annee}` convention explicitly (§4).

All open questions answered — the plan is ready for implementation. Remaining proposed defaults to keep in mind while coding: D1 (authors as strings), D2 (keep legacy fields), D5–D8.
