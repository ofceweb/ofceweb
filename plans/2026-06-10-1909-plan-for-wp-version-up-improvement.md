# Plan: Improve `wp_version_up()` to handle missing versioning

## Problem
Currently, `wp_version_up()` aborts if the `version` field is missing in `_quarto.yml`. This requires the user to manually add `version: v0` and update the `site-path` before they can use the function for the first time.

## Goal
Automate the initial versioning step. If no version is present, `wp_version_up()` should:
1. Initialize the version to `"v0"`.
2. Update the `_quarto.yml` file to include `version: v0`.
3. Update the `site-path` in `_quarto.yml` to include `/v0` as the last segment.
4. Proceed with the rest of the function (updating GitHub vars and manifest).

## Proposed Changes

### 1. Modify `R/wp_version_up.R`
- Change the logic in the `if (is.null(yml$version))` block (lines 43-49).
- Instead of `cli::cli_abort`, set `new_version <- "v0"`.
- Ensure that `yml$version` is assigned `new_version`.
- Ensure that the code follows the existing logic for updating `yml$version` and `yml$website$`site-path``.

## Implementation Steps
1. [ ] Modify `wp_version_up()` to initialize `new_version <- "v0"` when `yml$version` is `NULL`.
2. [ ] Remove the `cli::cli_abort` for missing version.
3. [ ] Ensure `yml$version <- new_version` is executed.
4. [ ] Verify that the `site-path` update logic correctly handles the transition from a non-versioned path to a versioned one.
5. [ ] Test the change (to be done in a real environment).
