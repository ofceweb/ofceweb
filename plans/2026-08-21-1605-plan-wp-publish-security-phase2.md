# Plan: WP publish security — Phase 2 (human approval gate)

Status: **not started** — awaiting decision on Option A vs Option B below.
Superseded in priority by
`plans/2026-08-21-1611-plan-wp-central-registry.md`, which proposes an
admin-declared central registry as the primary publish-authorization
mechanism instead of a per-deploy Environment reviewer gate. Keep this file
on record as an optional additional per-deploy check if OFCE later wants
routine republishes (not just initial registration) individually reviewed.

## Background

Phase 1 (implemented, commit `251e662`) added a manifest-based anti-collision
check: `wp_manifest()` records `source-repo` (`"owner/repo"`) in
`manifest.json`, and `ftp_deploy.yml` refuses to overwrite a live WP whose
deployed manifest has a different `source-repo`. This stops the common case of
accidentally reusing an `{annee, wp}` number across repos.

**Known gap:** `ftp_deploy.yml` is still an unprotected `workflow_dispatch`.
Anyone with write access to a WP repo can trigger it and push straight to live
FTP, with no human review step. A determined actor could also dodge the
anti-collision check entirely by choosing an unused `custom_version` string.
Phase 2 is meant to put a human in the loop before any live FTP publish,
regardless of path collisions.

## Constraints discovered this session

- GitHub protected **Environments** are always repo-scoped; there is no
  mechanism to share one environment/reviewer-gate object across multiple
  repos at the organization level. Org/enterprise "policies" only control
  administrative settings (e.g. base permissions, repo creation), not
  environment protection rules.
- Native **required reviewers** / **wait timer** protection rules require
  either GitHub Enterprise, or a **public** repository. Environments,
  environment secrets, and deployment-branch restrictions do work on private
  repos on GitHub Team/Pro — only the reviewer/wait-timer rules are gated.
- **OFCE's actual setup:** WP repos can be *either* public or private, and the
  org is on **GitHub Team**. This means a naive `environment: wp-publish` +
  native required reviewers would protect public WP repos but silently do
  nothing on private ones (the "Required reviewers" section wouldn't even
  appear in repo settings) — an inconsistent, easy-to-miss security posture.

## Options

### Option A — accept the asymmetry
- Add `environment: wp-publish` + native required reviewers to
  `ftp_deploy.yml`.
- Works automatically on public WP repos.
- Private WP repos get **no additional gate** beyond Phase 1's anti-collision
  check (unless/until the org upgrades to GitHub Enterprise).
- Pros: zero extra code, uses GitHub's built-in UI/audit trail.
- Cons: inconsistent protection across the WP repo fleet; risk that admins
  assume private repos are protected when they aren't.

### Option B — uniform third-party manual-approval step (leaning this way)
- Use a plan-agnostic Action such as `trstringer/manual-approval` inside
  `ftp_deploy.yml` (or a similar approach: create a tracking Issue and pause
  the job until a designated approver comments/reacts).
- Works identically regardless of repo visibility or GitHub plan tier — no
  dependency on Enterprise.
- Can still optionally keep `environment: wp-publish` (without relying on its
  reviewer rule) purely to scope FTP/staticrypt secrets as environment
  secrets, since environment secrets *do* work on private Team repos.
- Cons: adds a third-party Action dependency; `setup_wp()` needs new
  migration logic (parallel to the Phase 1 `FTP_SERVER_DIR` /
  anti-collision migrations) to inject this step into existing
  `ftp_deploy.yml` files.

## Open decisions (need user input before implementing)

1. **Option A vs Option B** — leaning towards B for uniform coverage across
   public/private WP repos, but not yet confirmed by the user.
2. If Option B: **who is the approver** for each repo? Options:
   - A fixed OFCE web-admin team/user baked into the template.
   - A placeholder that `setup_wp()` leaves for each repo maintainer to fill
     in (similar to how FTP secrets are per-repo).
3. Whether to keep `environment: wp-publish` alongside Option B purely for
   secret scoping (recommended, but adds a small amount of extra setup: an
   admin still needs to create the environment + move secrets into it on each
   repo, since environment creation only auto-provisions with no protection
   rules on first reference).

## Suggested implementation steps (once decision is made)

1. Update `inst/setup_wp/.github/workflows/ftp_deploy.yml` template:
   - Add the manual-approval step (Option B) or `environment:` block
     (Option A) after the existing anti-collision step.
2. Add idempotent migration logic in `setup_wp()` (section 10c or a new
   10d), following the existing pattern used for `FTP_SERVER_DIR` and the
   anti-collision step: detect absence of the new step/key in an existing
   `ftp_deploy.yml` and inject it without disturbing user customizations.
3. Add/extend tests in `tests/testthat/test-wp_manifest.R` or a new
   `test-ftp_deploy_migration.R` covering:
   - Fresh `setup_wp()` output includes the new gate.
   - Migration on a legacy `ftp_deploy.yml` (with and without the Phase 1
     anti-collision step already present).
4. Document the change in `NEWS.md` under the v0.8.2 (or next) section.
5. If Option B chosen with per-repo approver placeholders, document in
   `setup_wp()`'s roxygen/help text and in the generated workflow file's
   comments how a repo maintainer configures the approver.
6. Manually verify end-to-end on a scratch repo: trigger `workflow_dispatch`,
   confirm the job pauses for approval, confirm it proceeds only after
   approval and still respects the Phase 1 anti-collision check.

## Non-goals for this phase

- No changes to `check_wp()` (citation validation was explicitly declined
  this session; unrelated to this plan).
- No attempt to unify environments across repos at the org level — confirmed
  not possible on GitHub's current model.
