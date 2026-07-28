local M = {}

function M.format_virt_text(id, comment_text)
	local lines = vim.split(comment_text, "\n", { plain = true })
	local first_line = vim.trim(lines[1] or "")

	first_line = first_line:gsub("^[>#+*%-]+%s*", "")

	local max_length = 30
	local needs_ellipsis = false

	if #first_line > max_length then
		first_line = first_line:sub(1, max_length)
		needs_ellipsis = true
	elseif #lines > 1 then
		needs_ellipsis = true
	end

	local preview = first_line
	if needs_ellipsis then
		preview = preview .. "..."
	end

	return "💬 " .. id .. ". " .. preview
end

function M.place(comment, namespace)
	if not comment.bufnr or not vim.api.nvim_buf_is_valid(comment.bufnr) then
		return nil
	end

	local line_count = vim.api.nvim_buf_line_count(comment.bufnr)
	local marker_line = math.min(math.max(comment.line, 1), line_count)
	local virt_text_label = M.format_virt_text(comment.id, comment.comment)

	return vim.api.nvim_buf_set_extmark(comment.bufnr, namespace, marker_line - 1, 0, {
		virt_text = { { virt_text_label, "DiagnosticInfo" } },
		virt_text_pos = "eol",
	})
end

function M.delete(comment, namespace)
	if comment.bufnr and vim.api.nvim_buf_is_valid(comment.bufnr) then
		vim.api.nvim_buf_del_extmark(comment.bufnr, namespace, comment.extmark_id)
	end
end

function M.refresh(comment, namespace)
	M.delete(comment, namespace)
	comment.extmark_id = M.place(comment, namespace)
end

return M
