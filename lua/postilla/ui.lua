local M = {}

function M.open_comment_window(location, on_confirm, initial_text)
	local width = math.min(80, math.floor(vim.o.columns * 0.8))
	local height = math.min(12, math.floor(vim.o.lines * 0.4))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "markdown"
	vim.bo[bufnr].swapfile = false

	if initial_text and initial_text ~= "" then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(initial_text, "\n", { plain = true }))
	end

	local winid = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = string.format(" Review %s:%d ", location.file, location.line),
		title_pos = "center",
	})

	vim.wo[winid].wrap = true
	vim.wo[winid].linebreak = true

	local function close_window()
		if vim.api.nvim_win_is_valid(winid) then
			vim.api.nvim_win_close(winid, true)
		end
	end

	local function confirm()
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local comment = vim.trim(table.concat(lines, "\n"))

		close_window()

		if comment == "" then
			vim.notify("Postilla comment cancelled: empty comment", vim.log.levels.INFO)
			return
		end

		on_confirm(comment)
	end

	vim.keymap.set("n", "<C-s>", confirm, { buffer = bufnr, nowait = true, desc = "Save Postilla comment" })
	vim.keymap.set("i", "<C-s>", confirm, { buffer = bufnr, nowait = true, desc = "Save Postilla comment" })
	vim.keymap.set("n", "<Esc>", close_window, { buffer = bufnr, nowait = true, desc = "Cancel Postilla comment" })

	vim.api.nvim_win_set_cursor(winid, { vim.api.nvim_buf_line_count(bufnr), 0 })
	vim.cmd.startinsert()
end

return M
