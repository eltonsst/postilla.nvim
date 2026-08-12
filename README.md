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

- Add multiline comments to exact source lines.
- Write in a bottom split while the reviewed code stays visible.
- See saved comments as virtual text in the source file.
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

Write your comment in the bottom split:

- `<C-s>` saves the comment and returns to the source file.
- `<Esc>` in Normal mode cancels it.

Repeat this for every line you want to review. Saved comments look like this:

```text
💬 R1. Consider extracting this helper...
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
| `:PostillaComment` | Comment on the current line |
| `:PostillaList` | List comments in quickfix |
| `:PostillaEdit R1` | Edit comment `R1` |
| `:PostillaDelete R1` | Delete comment `R1` |
| `:PostillaStatus` | Show the current review status |
| `:PostillaDone` | Copy the review and finish |
| `:PostillaAbort` | Discard the current review |

## Output

Postilla uses the revdiff annotation format:

```markdown
## lua/postilla/init.lua:42 ( )
Please simplify this branch.

## README.md:80 ( )
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
  state_dir = nil,
  comment_window = {
    layout = "bottom",
    height = 10,
    width = 80,
  },
})
```

- `context_lines`: lines saved before and after the reviewed line.
- `keymap`: Normal-mode shortcut for adding a comment.
- `state_dir`: custom directory for Postilla state.
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
and markers will be restored.

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

Postilla is an experimental MVP. Today it creates line-level comments in
regular files. Diff views and range comments are not available yet.

## License

[MIT](LICENSE)
