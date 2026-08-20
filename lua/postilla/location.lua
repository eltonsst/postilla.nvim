local paths = require("postilla.paths")
local anchors = require("postilla.anchors")

local M = {}

function M.project_root_for_current_buffer()
	return paths.project_root_for(vim.api.nvim_buf_get_name(0))
end

function M.capture(context_lines, start_line, end_line)
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	local root = paths.project_root_for(path)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local first_line = math.min(math.max(start_line or cursor_line, 1), line_count)
	local last_line = math.min(math.max(end_line or first_line, 1), line_count)

	if first_line > last_line then
		first_line, last_line = last_line, first_line
	end

	local context_before =
		vim.api.nvim_buf_get_lines(bufnr, math.max(0, first_line - 1 - context_lines), first_line - 1, false)
	local target_lines = vim.api.nvim_buf_get_lines(bufnr, first_line - 1, last_line, false)
	local context_after =
		vim.api.nvim_buf_get_lines(bufnr, last_line, math.min(line_count, last_line + context_lines), false)
	local is_range = last_line > first_line

	return {
		bufnr = bufnr,
		root = root,
		file = paths.relative_path(root, path),
		line = first_line,
		start_line = first_line,
		end_line = is_range and last_line or nil,
		scope = is_range and "range" or "line",
		target = table.concat(target_lines, "\n"),
		fingerprint = anchors.fingerprint(table.concat(target_lines, "\n")),
		context_before = context_before,
		context_after = context_after,
	}
end

return M
