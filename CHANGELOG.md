# Changelog

## Unreleased

### Added

- Line-range comments through Visual-mode keymaps and Ex command ranges.
- Range highlighting while writing and range locations in the comment editor.
- Extmark anchors that follow edited buffers and relocate restored comments.
- Stale comment detection with warning markers and safe export blocking.
- Next and previous comment navigation with optional keymaps.
- Review preview with source jumps and non-destructive export.
- Virtual-line markers and clearer comment-editor controls.

### Changed

- `:PostillaDone` remains the finishing action; `:PostillaExport` now copies
  and saves feedback without clearing the active session.

## v0.2.0 - 2026-08-12

Postilla rename, external state storage, and RevDiff output release.

### Added

- Project-scoped session and output storage below Neovim's state directory.
- Automatic migration of valid `.local-review/session.json` and
  `.local-review/last-review.md` files.
- Collision-resistant project identifiers based on canonical paths.
- RevDiff-compatible line, range, and file-level annotation formatting.
- Session schema fields for annotation scope, ranges, and change types.
- Bottom-split comment editor that keeps the reviewed source visible, with the
  previous floating layout available through configuration.

### Changed

- Renamed the plugin from `local-review.nvim` to `postilla.nvim`.
- Renamed the Lua module to `postilla`, commands to the `Postilla` prefix,
  help to `:help postilla`, and healthcheck to `:checkhealth postilla`.
- Changed `:PostillaDone` output from a custom agent prompt to deterministic
  RevDiff annotation records.
- Made state writes atomic and exposed the active state path in
  `:PostillaStatus`.
- Saving a comment now returns focus to the reviewed buffer in Normal mode.

### Removed

- Project-root state files for new sessions.
- The legacy `local_review` Lua module and `LocalReview` commands.

## v0.1.4 - 2026-05-05

Stability refactor and compact prompt release.

### Added

- Headless Neovim unit tests for prompt, marker, path, and session helpers.
- CI step that runs the unit test suite.

### Changed

- Split the main runtime module into focused modules for paths, location
  capture, markers, prompt generation, session persistence, state, and UI.
- Simplified the generated review prompt to a compact comment list with target
  lines.
- Render multiline review comments as markdown quote blocks in the generated
  prompt.
- Polished README content for plugin users.

## v0.1.3 - 2026-05-05

Review marker preview release.

### Added

- Compact virtual text review markers with comment previews.
- Updated demo screenshot showing the new marker UI.
- Git ignore entry for local `AGENT_CONTEXT.md` handoff files.

### Changed

- Shortened review marker previews to 30 characters.
- Refreshed review markers immediately after editing an existing comment.
- Updated README and vimdoc marker examples.

## v0.1.2 - 2026-05-05

Neovim public polish release.

### Added

- Vim help documentation at `doc/local-review.txt`.
- Healthcheck support with `:checkhealth local_review`.
- README demo screenshot.
- README feature list and clearer dependency fallback notes.
- CI smoke coverage for help tags, help lookup, and healthcheck.

## v0.1.1 - 2026-05-05

Public readiness release.

### Added

- Public-facing README sections for motivation, quick demo, and manual
  verification.
- Stylua formatting configuration.
- GitHub Actions CI for formatting and a headless Neovim smoke test.

### Changed

- Documented Neovim 0.10+ as the supported minimum version.
- Formatted Lua code with Stylua.

## v0.1.0 - 2026-05-05

Initial MVP release.

### Added

- Local review sessions with `:LocalReviewStart`, `:LocalReviewDone`, and
  `:LocalReviewAbort`.
- Multiline floating markdown input for review comments.
- Inline virtual text markers for stored comments.
- Review comment list, edit, and delete commands.
- Markdown prompt generation copied to the system clipboard.
- Backup prompt written to `.local-review/last-review.md`.
- Session backup and restore with `.local-review/session.json`.
- Optional setup with configurable context line count and comment keymap.
