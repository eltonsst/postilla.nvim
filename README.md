# postilla.nvim

[![CI](https://github.com/eltonsst/postilla.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/eltonsst/postilla.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io/)

Local inline review comments for AI-agent coding workflows.

This plugin lets you leave review comments at the line you are reading in
Neovim, without modifying source files and without opening a GitHub or GitLab
review. When you are done, it generates structured annotations that you can
paste into Codex or another coding agent.

## Why This Exists

AI coding agents are good at making local changes, but reviewing those changes
with localized comments is still awkward. Opening a remote pull request can be
too public or too heavy for experimental work, while writing notes in a separate
file loses the exact code location.

`postilla.nvim` keeps the review loop local:

1. Let an agent modify code.
2. Review the changes in Neovim.
3. Leave inline comments without changing source files.
4. Export structured RevDiff annotations.
5. Paste the annotations back into the agent.

## Features

- Floating multiline markdown comment window.
- Inline virtual text markers without modifying source files.
- Quickfix list for collected review comments.
- Edit and delete review comments before export.
- RevDiff-compatible annotations copied to the clipboard.
- Session and output backups stored under Neovim's state directory.
- Automatic migration from the legacy `.local-review/` project directory.
- `:help postilla` and `:checkhealth postilla` support.

## Status

Experimental MVP.

The current version stores comments in memory and writes project-scoped backups
under `stdpath("state")/postilla`. `:PostillaStart` restores the current
project's session when it finds one.

## Requirements

- Neovim 0.10 or newer
- Git is optional, but recommended for project-relative file paths
- Clipboard support if you want `:PostillaDone` to copy to the system
  clipboard

If Git is unavailable or the current file is outside a Git repository, paths
fall back to Neovim's current working directory when possible.

If clipboard support is unavailable, `:PostillaDone` still writes the output
under Neovim's state directory.

## Installation

With lazy.nvim:

```lua
{
  "eltonsst/postilla.nvim",
  config = function()
    require("postilla").setup({
      keymap = "<leader>rc",
    })
  end,
}
```

The plugin also works without calling `setup()`. In that case, use the commands
directly.

After installing, Neovim should generate help tags automatically through your
plugin manager. If not, run:

```vim
:helptags ALL
```

Then open the help page:

```vim
:help postilla
```

You can also check local requirements:

```vim
:checkhealth postilla
```

## Quick Demo

```vim
:PostillaStart
:PostillaComment
```

Write a multiline markdown comment in the floating window, then press `<C-s>`.
The reviewed line shows virtual text like:

```text
💬 R1. Consider extracting this...
```

Inspect collected comments:

```vim
:PostillaList
```

Finish and copy the generated annotations:

```vim
:PostillaDone
```

## Usage

Start a review session:

```vim
:PostillaStart
```

Add a comment at the current cursor line:

```vim
:PostillaComment
```

This opens a floating markdown buffer.

- Write your review comment.
- Press `<C-s>` to save it.
- Press `<Esc>` in normal mode to cancel.

Saved comments are shown with virtual text at the reviewed line, such as:

```text
💬 R1. Consider extracting this...
```

Finish the review:

```vim
:PostillaDone
```

This command:

- builds RevDiff-compatible annotations
- copies it to the `+` clipboard register
- saves a backup under Neovim's state directory
- removes the active session backup
- clears the in-memory session and virtual text markers

Abort the review:

```vim
:PostillaAbort
```

This clears the in-memory session and virtual text markers without generating
output. It also removes the active session backup.

Check current review state:

```vim
:PostillaStatus
```

This shows whether a session is active, how many comments are stored, the
latest comment location, and the state path.

List current review comments:

```vim
:PostillaList
```

This opens the quickfix list with one item per stored comment. Press Enter on a
quickfix item to jump back to the reviewed line.

Delete a review comment:

```vim
:PostillaDelete R1
```

This removes the stored comment and clears its virtual text marker.

Edit a review comment:

```vim
:PostillaEdit R1
```

This reopens the floating markdown buffer with the existing comment text. Saving
updates the stored comment while keeping the same review ID and marker.

## Configuration

Default configuration:

```lua
require("postilla").setup({
  context_lines = 5,
  keymap = nil,
  state_dir = nil,
})
```

Options:

- `context_lines`: number of lines captured before and after the reviewed line
- `keymap`: optional normal-mode mapping for `:PostillaComment`
- `state_dir`: optional override for Postilla's Neovim state directory

Example:

```lua
require("postilla").setup({
  context_lines = 3,
  keymap = "<leader>rc",
})
```

## Annotation Output

The output follows RevDiff's structured annotation format:

- `## path:line (type)` for a line
- `## path:start-end (type)` for a range
- `## path (file-level)` for a file note

Example:

```markdown
## lua/postilla/init.lua:42 ( )
Please simplify this branch.

## README.md:80 ( )
Tighten this section.
Keep it focused on users.
```

Postilla currently comments on normal working buffers, so exported line
annotations use RevDiff's context type `( )`. The internal format already
supports added `(+)`, removed `(-)`, ranges, and file-level notes for future
diff-aware integrations.

## Session Backup

While a review is active, comments are stored in a project-specific directory
below:

```text
stdpath("state")/postilla/projects/
```

The session backup is updated when comments are added, edited, or deleted. It is
removed by `:PostillaDone` and `:PostillaAbort`.

If Neovim closes before the review is done, reopen the project and run:

```vim
:PostillaStart
```

The plugin restores the saved comments and recreates markers for files that
still exist locally. Run `:PostillaStatus` to see the exact session path.

When Postilla finds state produced by `local-review.nvim` in
`.local-review/`, it migrates valid files into Neovim's state directory and
removes the old directory when it is empty.

## Migrating from local-review.nvim

Postilla v0.2 is a clean rename. Update the plugin specification and setup:

```lua
{
  "eltonsst/postilla.nvim",
  config = function()
    require("postilla").setup()
  end,
}
```

Commands now use the `Postilla` prefix:

```text
LocalReviewStart   → PostillaStart
LocalReviewComment → PostillaComment
LocalReviewDone    → PostillaDone
```

The legacy Lua module and commands are not retained. Valid state from the old
`.local-review/` directory is migrated automatically the first time
`:PostillaStart` runs for that project.

## Current Limitations

- The UI currently creates line-level context annotations only.
- There are no integrations with diffview.nvim, fugitive, or gitsigns yet.

## License

MIT
