---

editor_options: 
  markdown: 
    wrap: 72
---

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

- New repo, e.g. `ofce/wp-registry`.
- **Recommended visibility: public.** The registry only maps `{annee, wp} → source-repo`, not WP titles/content, so there's little to leak, and public visibility means `ftp_deploy.yml` can read it with a plain unauthenticated `curl` to `raw.githubusercontent.com` — no token/secret needs to be distributed to every WP repo just to perform the read-only authorization check.
- If privacy of the mapping itself is considered sensitive, fall back to private + an org-level read-only PAT/GitHub App token (e.g. `WP_REGISTRY_TOKEN`) shared to all WP repos as an org secret. This adds credential-distribution overhead; only do this if there's a concrete reason the mapping must stay private.

### Registry schema

A single `registry.json` (or `registry.yml`) at the repo root, one entry per `{annee, wp}` pair (not per version — this is what closes the `custom_version` bypass):

``` json
{
  "wp": [
    {
      "annee": 2026,
      "wp": 15,
      "source-repo": "ofce/wp-2026-15-titre-du-document",
      "registered-by": "xtimbeau",
      "registered-at": "2026-08-21"
    }
  ]
}
```

### Governance (how an admin "declares" a WP)

- Branch protection on `wp-registry`'s default branch: disallow direct pushes, require pull request review, and use a `CODEOWNERS` file naming a `wp-admins` team as required reviewers for `registry.json`.
- Branch protection + required PR review is broadly available across GitHub plans (unlike the Environment required-reviewers feature, which needs Enterprise for private repos) — this needs a final confirmation against current GitHub docs before relying on it, but has historically been a long-standing feature independent of the newer Environments gating.
- Only a merged PR (i.e., admin approval) creates a valid registry entry.

### Registration workflow (two options, not mutually exclusive)

**A. Manual (day-one fallback).** The WP repo's maintainer opens a PR against `wp-registry` by hand, adding their `{annee, wp, source-repo}` row. An admin reviews and merges. No new `ofceweb` code required beyond documenting the schema and providing a PR template.

**B. Semi-automated (target design).** A new helper, working name `wp_registry_request()`, computes `{annee, wp, source-repo}` from the local `_quarto.yml`/`manifest.json` and opens the PR against `wp-registry` automatically (via `gh`/`gert`, consistent with `ofceweb`'s existing git tooling). The human review/merge gate is unchanged; this only removes manual JSON editing and the risk of malformed/mismatched entries. Could be invoked from `setup_wp()` interactively, or as a standalone exported function.

### Publish-time verification (`ftp_deploy.yml` changes)

Add a step immediately after checkout, before any FTP/staticrypt secrets are used (same position as today's Phase 1 anti-collision step — likely replacing it, see "Relationship to Phase 1" below):

1.  Compute `{annee, wp}` for this run (from `manifest.json`/`_quarto.yml`).
2.  Fetch `registry.json` from `wp-registry`'s default branch (plain `curl`, no auth needed if the registry is public).
3.  Look up the entry for `{annee, wp}`:
    - **No entry** → fail with `::error::` — *"WP {annee}/{wp} is not registered in wp-registry. Contact an OFCE web admin to register this repository before publishing."* This is a behavior change from Phase 1, which allowed an unregistered first deploy to pass silently; now every publish, including the first, requires prior registration.
    - **Entry found, `source-repo` matches `github.repository`** → proceed.
    - **Entry found, mismatch** → fail, same message/semantics as today's Phase 1 check, but now unconditional (keying on `{annee, wp}` rather than the live manifest closes the `custom_version` bypass).

### Relationship to Phase 1's existing manifest check

Recommend **keeping both** as defense-in-depth: - Registry check → authorizes *who* may publish to `{annee, wp}` at all. - Live-manifest check (existing) → catches the narrower case where the currently-deployed manifest at the *exact target subpath* disagrees with what's expected, even from an already-authorized repo (e.g. stale/partial deploys, manual FTP tampering).

### Relationship to the Phase 2 (Environment) plan

This registry scheme substantially reduces the need for a per-deploy reviewer gate: the human-in-the-loop moment moves from *"before every FTP push"* to *"before a repo is ever authorized to claim a WP number,"* which happens once per WP rather than on every render/republish cycle. It also sidesteps the GitHub plan/visibility limitations that made the Environment approach inconsistent across OFCE's public/private WP repo mix.

**Recommendation:** treat this registry scheme as the primary replacement for Phase 2. Keep the Environment/manual-approval-Action idea from `2026-08-21-1605-plan-wp-publish-security-phase2.md` on file only as an optional additional per-deploy gate, to be revisited if OFCE later decides routine re-publishes of an already-registered WP also need individual review (not just the initial registration).

## Migration / backfill

Already-published WPs need a one-time baseline import into `wp-registry` so they don't get locked out under the new "must be registered" rule. This is an administrative, largely manual task: - Enumerate existing live WPs (from OFCE's FTP tree / existing `manifest.json` files, or an internal list of published working papers) and their known `source-repo` (from Phase 1's manifest field, where present). - Compile into one bulk PR against `wp-registry`, reviewed/merged by an admin as the initial baseline. - Not automatable from `ofceweb` alone since it requires enumerating the live FTP tree outside the package's normal write path — a one-off script or manual compilation is fine here.

## New/changed `ofceweb` pieces (once decisions below are made)

- `ftp_deploy.yml` template: replace (or augment) the Phase 1 anti-collision step with the registry-lookup step described above.
- `setup_wp()`: idempotent migration logic (parallel to the existing `FTP_SERVER_DIR`/anti-collision migrations) to inject the registry check into a pre-existing `ftp_deploy.yml` that lacks it.
- Optional `wp_registry_check()` (R-level pre-flight check, so a contributor can verify registration locally before pushing) and/or `wp_registry_request()` (Option B automation above).
- New tests covering: registered match passes, unregistered fails, mismatched `source-repo` fails, and (if Option B implemented) PR-creation logic against a mocked registry repo.
- `wp-registry` itself needs a `README.md` documenting the schema, how to request a number, and admin review responsibilities — this lives in the new repo, not in `ofceweb`.
- `NEWS.md` entry once implemented.

## Open decisions (need user/admin input before implementing)

1.  Registry repo name and location (`ofce/wp-registry` assumed above) and final visibility choice (public recommended; private only if there's a concrete confidentiality reason).
2.  Registration workflow: manual PRs only (A), or build the `wp_registry_request()` automation (B)?
3.  Keep Phase 1's live-manifest check alongside the new registry check, or retire it once the registry is authoritative?
4.  Who sits on the `wp-admins` CODEOWNERS/reviewer team for `wp-registry`?
5.  Who performs the one-time migration/backfill of already-published WPs, and what's the source of truth for that initial list?
6.  Confirm current GitHub docs on branch-protection/required-PR-review availability across plans/visibility, to make sure this mechanism doesn't have its own hidden plan-tier gate (unlikely, but worth a quick check given the surprises found with Environments).

## Defense against workflow tampering

The registry check only helps if it actually runs unmodified. Anyone with
write access to a WP repo can edit that repo's own `ftp_deploy.yml` — GitHub
does not otherwise prevent repo maintainers from editing their own workflow
files. Two tiers of mitigation, in increasing order of effort:

### Tier 1 — require admin review to change the workflow (recommended default)

**Important correction:** ordinary repo-level branch protection is not
sufficient on its own. Configuring/editing branch protection requires admin
access to *that* repo, and WP repo authors are commonly also the repo's
admin — so a repo-level rule and the person it's meant to constrain share
the same trust boundary; that admin could simply loosen or delete the rule.

The fix is to use an **organization-level ruleset** instead of (or in
addition to) repo-level branch protection:

- An OFCE **org owner** (not a WP repo's own admin) creates one
  organization-level ruleset targeting all WP repos (e.g. by a `wp-*` name
  pattern), requiring PRs and a `CODEOWNERS`-based admin-team review for
  changes to `.github/workflows/**`.
- If a repository is targeted by an organization-level ruleset, only
  organization owners can edit that ruleset — a WP repo's own admin can add
  *additional* repo-level rulesets on top, but cannot weaken or remove the
  org-level one; the two aggregate, with the most restrictive version of any
  overlapping rule applying.
- Bypass is opt-in and org-owner-controlled: repository-admin status does
  **not** automatically grant bypass of an org-level ruleset unless the org
  owner explicitly adds that role to the ruleset's bypass list — leave it
  off for `wp-*` repos.
- **Plan availability:** this required GitHub Enterprise until recently, but
  organization rulesets can now be targeted and enforced at the organization
  level for GitHub Team plan customers as of mid-2025 — no plan upgrade
  needed for OFCE's current GitHub Team subscription.
- Combine with the Environment's **"Deployment branches and tags"**
  restriction (works on private repos on GitHub Team, unlike required
  reviewers) set to the protected branch only, so a `workflow_dispatch` run
  from a scratch/unmerged branch with a tampered workflow still can't obtain
  the FTP secrets.
- Net effect: bypassing the check requires either an org owner's own
  cooperation, or getting a malicious diff past a required admin reviewer —
  the same trust boundary already relied on for `wp-registry` itself. No new
  infrastructure needed beyond the one org-level ruleset.

#### Draft implementation artifacts

**Organization ruleset**, created via `POST /orgs/{org}/rulesets` (or the
equivalent `gh api`/Terraform call) by an org owner. Targets every repo
matching a `wp-*` naming convention (adjust the pattern to OFCE's actual
convention) and enforces PR-based changes with required `CODEOWNERS` review
on the default branch:

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

Notes:
- `bypass_actors` deliberately omits `RepositoryAdmin` — including it would
  re-open the exact loophole this ruleset exists to close. The single team
  entry (with `bypass_mode: "pull_request"`) is an optional break-glass path
  that still requires a PR, just skips the required-review count; omit it
  entirely if no such escape hatch is wanted.
- `require_code_owner_review: true` enforces admin sign-off on
  `.github/workflows/**` specifically only in combination with the
  `CODEOWNERS` entry below — the ruleset itself doesn't know about paths;
  `CODEOWNERS` is what maps that directory to the admin team.
- **Unverified against live docs:** whether the newer path-scoped
  "required review from a specific team for changes to specific
  files/directories" capability is exposed as its own rule type or as
  additional `pull_request` parameters in the current ruleset API, and the
  exact `actor_type`/`actor_id` shape for a `Team` bypass entry. Both should
  be dry-run against a test ruleset (or checked in current GitHub API docs)
  before rollout; the `CODEOWNERS`-based approach above avoids depending on
  either being confirmed, since its schema is stable and well-documented.

**`CODEOWNERS`**, added to each WP repo (candidate for `setup_wp()` to
scaffold automatically):

```
# .github/CODEOWNERS
/.github/workflows/  @ofce/web-admins
```

This routes review of any change under `.github/workflows/` (including
`ftp_deploy.yml`) to the `@ofce/web-admins` team, while leaving other files
free to be approved by whichever reviewers a repo's own norms call for.

### Tier 2 — never expose FTP credentials to the WP repo at all (stronger, more effort)

- Store FTP/staticrypt secrets as **organization secrets scoped to
  "Selected repositories" = a new admin-only repo** (e.g. `ofce/wp-deploy`),
  not the individual WP repos, so no edit to a WP repo's own YAML can ever
  reach the secret.
- WP repos only render the site and publish a build artifact/deploy branch;
  the actual FTP push and registry check run entirely inside
  `ofce/wp-deploy`'s own (admin-only-editable) workflow.
- Triggering `ofce/wp-deploy` from a WP repo (`repository_dispatch` or
  similar) cannot rely on a self-reported payload for identity (a tampered
  caller workflow could lie about which repo/version it represents).
  Instead, `ofce/wp-deploy`'s workflow must independently query the GitHub
  API for the actual triggering repository/branch/commit and read
  `manifest.json` from that verified location itself before checking it
  against `wp-registry`.
- More infrastructure (a second repo, a trigger/hand-off mechanism) — treat
  as an escalation path if Tier 1 is ever judged insufficient, not a day-one
  requirement.

**Recommendation:** start with Tier 1; it's proportionate to an internal
contributor threat model and reuses infrastructure already implied by the
registry's own governance. Revisit Tier 2 only if a stronger threat model
(e.g. untrusted external contributors) becomes relevant.

## Non-goals for this phase

- No changes to `check_wp()` (citation validation was explicitly declined in an earlier session; unrelated to this plan).
- Not attempting to unify GitHub Environments across repos at the org level — confirmed not possible on GitHub's current model (see Phase 2 plan).
- Does not by itself add per-deploy human review for already-registered repos' routine republishes (see "Relationship to Phase 2" above).
