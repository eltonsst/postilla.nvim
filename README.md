# postilla.nvim

[![CI](https://github.com/eltonsst/postilla.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/eltonsst/postilla.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io/)

**Review the code your agent wrote, line by line, inside Neovim.**

Postilla lets you attach comments to source lines without changing the files.
When the review is done, it copies structured feedback to your clipboard, ready
to paste into Codex or another coding agent.

No pull request. No temporary notes. No files to add to `.gitignore`.

## Features

- Add multiline comments to exact lines or line ranges.
- Write in a bottom split while the reviewed code stays visible.
- Keep comments attached when code moves and warn when reviewed code changes.
- Jump between comments and preview the final feedback inside Neovim.
- List, edit, and delete comments before export.
- Restore unfinished reviews after restarting Neovim.
- Export [revdiff](https://github.com/umputun/revdiff)-compatible feedback.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "eltonsst/postilla.nvim",
  opts = {
    keymap = "<leader>rc",
    next_keymap = "]r",
    previous_keymap = "[r",
  },
}
```

Postilla also works without `setup()`. You can use its commands directly.

## Review in 60 seconds

Start a review:

```vim
:PostillaStart
```

Move the cursor to a line and add a comment:

```vim
:PostillaComment
```

If you configured the example keymap, press `<leader>rc` instead.

To comment on a range, select the lines in Visual mode and press `<leader>rc`.
Character and block selections are expanded to complete lines.

Write your comment in the bottom split:

- `<C-s>` saves the comment and returns to the source file.
- `<Esc>` in Normal mode cancels it.

Repeat this for every line you want to review. Saved comments look like this:

```text
💬 R1. Consider extracting this helper...
💬 R2 [80-84]. This section is too long...
```

Use `]r` and `[r` to move between comments with the example configuration.
Preview the complete feedback without ending the session:

```vim
:PostillaPreview
```

Finish the review:

```vim
:PostillaDone
```

Postilla copies all comments to the `+` clipboard register. Paste them into
your coding agent and continue the conversation.

## Commands

| Command | Action |
| --- | --- |
| `:PostillaStart` | Start or restore a review |
| `:PostillaComment` | Comment on the current line or selected range |
| `:PostillaNext` / `:PostillaPrev` | Jump between comments |
| `:PostillaList` | List comments in quickfix |
| `:PostillaEdit R1` | Edit comment `R1` |
| `:PostillaDelete R1` | Delete comment `R1` |
| `:PostillaPreview` | Preview feedback and jump to its comments |
| `:PostillaExport` | Copy and save feedback without finishing |
| `:PostillaStatus` | Show the current review status |
| `:PostillaDone` | Copy the review and finish |
| `:PostillaAbort` | Discard the current review |

## Output

Postilla uses the revdiff annotation format:

```markdown
## lua/postilla/init.lua:42 ( )
Please simplify this branch.

## README.md:80-84 ( )
This section is too long. Keep it focused on new users.
```

The output keeps every comment connected to its file and line. This makes the
feedback clear for both people and coding agents.

## Configuration

These are the default options:

```lua
require("postilla").setup({
  context_lines = 5,
  keymap = nil,
  next_keymap = nil,
  previous_keymap = nil,
  state_dir = nil,
  marker = {
    style = "virtual_line",
  },
  comment_window = {
    layout = "bottom",
    height = 10,
    width = 80,
  },
})
```

- `context_lines`: lines saved before and after the reviewed line.
- `keymap`: shortcut for adding a line or Visual-range comment.
- `next_keymap` and `previous_keymap`: optional navigation shortcuts.
- `state_dir`: custom directory for Postilla state.
- `marker.style`: use `"virtual_line"` or `"eol"`.
- `comment_window.layout`: use `"bottom"` or `"float"`.
- `comment_window.height`: height of the bottom split or float.
- `comment_window.width`: width of the float.

For the original floating editor:

```lua
require("postilla").setup({
  comment_window = {
    layout = "float",
  },
})
```

## Sessions

Postilla stores unfinished reviews outside your project:

```text
stdpath("state")/postilla/projects/
```

If Neovim closes, reopen the project and run `:PostillaStart`. Your comments
and markers will be restored. Postilla relocates comments when their exact code
moves. If the reviewed code changed or became ambiguous, it marks the comment
with `⚠` and blocks export until you delete and recreate that comment.

Users upgrading from `local-review.nvim` only need to use
`eltonsst/postilla.nvim`, `require("postilla")`, and the `Postilla*` commands.
Old `.local-review` state is migrated automatically.

## Requirements

- Neovim 0.10 or newer
- Git, recommended for project-relative file paths
- Clipboard support, recommended for `:PostillaDone`

Run `:checkhealth postilla` to check your setup. Full documentation is
available with `:help postilla`.

## Status

Postilla focuses on one job: reviewing agent changes in regular Neovim buffers
and returning precise feedback. It is not a diff or merge tool.

## License

[MIT](LICENSE)
