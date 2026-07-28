local paths = require("postilla.paths")

local M = {}

function M.project_root_for_current_buffer()
	return paths.project_root_for(vim.api.nvim_buf_get_name(0))
end

function M.capture(context_lines)
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	local root = paths.project_root_for(path)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line_count = vim.api.nvim_buf_line_count(bufnr)

	local context_before = vim.api.nvim_buf_get_lines(bufnr, math.max(0, row - 1 - context_lines), row - 1, false)
	local target = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
	local context_after = vim.api.nvim_buf_get_lines(bufnr, row, math.min(line_count, row + context_lines), false)

	return {
		bufnr = bufnr,
		root = root,
		file = paths.relative_path(root, path),
		line = row,
		target = target,
		context_before = context_before,
		context_after = context_after,
	}
end

return M
