local M = {}

local function location_label(location)
	local first_line = location.start_line or location.line
	if location.end_line and location.end_line > first_line then
		return string.format("%s:%d-%d", location.file, first_line, location.end_line)
	end
	return string.format("%s:%d", location.file, first_line)
end

local function create_comment_buffer(initial_text)
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "markdown"
	vim.bo[bufnr].swapfile = false

	if initial_text and initial_text ~= "" then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(initial_text, "\n", { plain = true }))
	end

	return bufnr
end

local function open_float(bufnr, location, options)
	local width = math.min(options.width or 80, math.floor(vim.o.columns * 0.8))
	local height = math.min(options.height or 12, math.floor(vim.o.lines * 0.4))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	return vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = string.format(" Review %s ", location_label(location)),
		title_pos = "center",
	})
end

local function open_bottom_split(bufnr, location, options)
	local max_height = math.max(3, math.floor(vim.o.lines * 0.4))
	local height = math.min(math.max(3, math.floor(options.height or 10)), max_height)
	vim.cmd(string.format("botright %dsplit", height))

	local winid = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(winid, bufnr)
	vim.api.nvim_win_set_height(winid, height)
	vim.wo[winid].winfixheight = true
	vim.wo[winid].winbar = vim.fn.escape(string.format(" Postilla · %s ", location_label(location)), "%")

	return winid
end

local function source_highlight(source_winid, location)
	if not location.bufnr or vim.api.nvim_win_get_buf(source_winid) ~= location.bufnr then
		return nil
	end

	local line_count = vim.api.nvim_buf_line_count(location.bufnr)
	local first_line = math.min(math.max(location.start_line or location.line, 1), line_count)
	local last_line = math.min(math.max(location.end_line or first_line, first_line), line_count)
	local range_pattern = string.format("\\%%>%dl\\%%<%dl.*", first_line - 1, last_line + 1)

	return vim.api.nvim_win_call(source_winid, function()
		vim.api.nvim_win_set_cursor(source_winid, { first_line, 0 })
		vim.cmd("normal! zz")
		return vim.fn.matchadd("Visual", range_pattern, 10)
	end)
end

function M.open_comment_window(location, on_confirm, initial_text, options)
	options = options or {}
	local layout = options.layout or "bottom"

	if layout ~= "bottom" and layout ~= "float" then
		error(string.format("Invalid Postilla comment window layout: %s", layout))
	end

	local source_winid = vim.api.nvim_get_current_win()
	local source_view = vim.api.nvim_win_call(source_winid, vim.fn.winsaveview)
	local bufnr = create_comment_buffer(initial_text)
	local winid

	if layout == "float" then
		winid = open_float(bufnr, location, options)
	elseif layout == "bottom" then
		winid = open_bottom_split(bufnr, location, options)
	end

	vim.wo[winid].wrap = true
	vim.wo[winid].linebreak = true

	local source_match_id = source_highlight(source_winid, location)
	local closed = false

	local function restore_source()
		if closed then
			return
		end
		closed = true

		if source_match_id and vim.api.nvim_win_is_valid(source_winid) then
			vim.api.nvim_win_call(source_winid, function()
				pcall(vim.fn.matchdelete, source_match_id)
			end)
		end

		if vim.api.nvim_win_is_valid(source_winid) then
			vim.api.nvim_set_current_win(source_winid)
			vim.api.nvim_win_call(source_winid, function()
				vim.fn.winrestview(source_view)
			end)
		end
	end

	local function close_window()
		if vim.api.nvim_win_is_valid(winid) then
			vim.api.nvim_win_close(winid, true)
		end
		restore_source()
	end

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(winid),
		once = true,
		callback = function()
			vim.schedule(restore_source)
		end,
	})

	local function confirm()
		-- An insert-mode mapping keeps Neovim in Insert mode even after its
		-- comment window is closed. Leave Insert mode before returning focus to
		-- the reviewed buffer so saving completes the comment interaction.
		vim.cmd.stopinsert()

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
