local location = require("postilla.location")
local markers = require("postilla.markers")
local revdiff = require("postilla.revdiff")
local session = require("postilla.session")
local state = require("postilla.state")
local storage = require("postilla.storage")
local ui = require("postilla.ui")

local M = {}

local config = {
	context_lines = 5,
	keymap = nil,
	comment_window = {
		layout = "bottom",
		height = 10,
		width = 80,
	},
}

local function next_comment_id()
	local id = "R" .. state.next_id
	state.next_id = state.next_id + 1
	return id
end

local function line_label(comment)
	local first_line = comment.start_line or comment.line
	if comment.end_line and comment.end_line > first_line then
		return string.format("%d-%d", first_line, comment.end_line)
	end
	return tostring(first_line)
end

local function restore_extmark(comment)
	local extmark_id = markers.place(comment, state.namespace)
	if extmark_id then
		comment.extmark_id = extmark_id
		state.buffers[comment.bufnr] = true
	end
end

local function save_session()
	session.save(state)
end

local function add_comment(review_location, comment_text)
	local id = next_comment_id()
	local comment = {
		id = id,
		bufnr = review_location.bufnr,
		root = review_location.root,
		file = review_location.file,
		line = review_location.line,
		start_line = review_location.start_line or review_location.line,
		end_line = review_location.end_line,
		change_type = " ",
		scope = review_location.scope or "line",
		target = review_location.target,
		context_before = review_location.context_before,
		context_after = review_location.context_after,
		comment = comment_text,
	}

	restore_extmark(comment)

	table.insert(state.comments, comment)
	state.root = state.root or review_location.root
	save_session()

	return comment
end

local function reset_state()
	local root = state.root

	for bufnr in pairs(state.buffers) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, state.namespace, 0, -1)
		end
	end

	state.active = false
	state.comments = {}
	state.buffers = {}
	state.next_id = 1
	state.root = nil

	session.delete(root)
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
	storage.setup({ state_dir = config.state_dir })

	if config.keymap then
		vim.keymap.set("n", config.keymap, M.comment, { desc = "Add Postilla comment" })
		vim.keymap.set("x", config.keymap, function()
			local anchor_line = vim.fn.line("v")
			local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
			M.comment(anchor_line, cursor_line)
		end, { desc = "Add Postilla range comment" })
	end
end

function M.start()
	if state.active then
		vim.notify("Postilla session already active", vim.log.levels.INFO)
		return
	end

	state.active = true
	local root = location.project_root_for_current_buffer()

	if session.load(root, state, restore_extmark) then
		vim.notify(string.format("Restored Postilla session with %d comment(s)", #state.comments), vim.log.levels.INFO)
		return
	end

	state.root = root
	vim.notify("Postilla session started", vim.log.levels.INFO)
end

function M.comment(start_line, end_line)
	if not state.active then
		M.start()
	end

	local review_location = location.capture(config.context_lines, start_line, end_line)
	ui.open_comment_window(review_location, function(comment)
		local stored = add_comment(review_location, comment)
		vim.notify(
			string.format("Stored review comment %s for %s:%s", stored.id, stored.file, line_label(stored)),
			vim.log.levels.INFO
		)
	end, nil, config.comment_window)
end

function M.done()
	if not state.active then
		vim.notify("No active Postilla session", vim.log.levels.INFO)
		return
	end

	if #state.comments == 0 then
		reset_state()
		vim.notify("No Postilla comments to export", vim.log.levels.INFO)
		return
	end

	local review_output = revdiff.build(state.comments)
	local saved_path, save_error = revdiff.save(review_output, state.comments[1].root)
	if not saved_path then
		vim.notify(string.format("Could not save Postilla output: %s", save_error), vim.log.levels.ERROR)
		return
	end
	local comment_count = #state.comments

	vim.fn.setreg("+", review_output)
	reset_state()

	vim.notify(
		string.format("Copied %d review comment(s) and saved %s", comment_count, saved_path),
		vim.log.levels.INFO
	)
end

function M.status()
	local session_status = state.active and "active" or "inactive"
	local message = string.format("Postilla session: %s\nComments: %d", session_status, #state.comments)
	message = message .. string.format("\nState: %s", state.root and session.path(state.root) or storage.root())
	local latest = state.comments[#state.comments]

	if latest then
		message = message .. string.format("\nLatest: %s at %s:%s", latest.id, latest.file, line_label(latest))
	end

	vim.notify(message, vim.log.levels.INFO)
end

function M.list()
	if #state.comments == 0 then
		vim.notify("No Postilla comments", vim.log.levels.INFO)
		return
	end

	local items = {}

	for _, comment in ipairs(state.comments) do
		local first_line = vim.split(comment.comment, "\n", { plain = true })[1] or ""
		local range = comment.end_line and string.format(" [%s]", line_label(comment)) or ""

		table.insert(items, {
			bufnr = comment.bufnr,
			lnum = comment.start_line or comment.line,
			col = 1,
			text = string.format("%s%s: %s", comment.id, range, first_line),
		})
	end

	vim.fn.setqflist({}, " ", {
		title = "Local Review Comments",
		items = items,
	})
	vim.cmd.copen()
end

function M.delete(id)
	id = vim.trim(id or "")

	if id == "" then
		vim.notify("PostillaDelete requires a comment id, for example R1", vim.log.levels.WARN)
		return
	end

	for index, comment in ipairs(state.comments) do
		if comment.id == id then
			markers.delete(comment, state.namespace)

			table.remove(state.comments, index)
			if #state.comments == 0 then
				session.delete(state.root)
			else
				save_session()
			end
			vim.notify(string.format("Deleted Postilla comment %s", id), vim.log.levels.INFO)
			return
		end
	end

	vim.notify(string.format("Postilla comment %s not found", id), vim.log.levels.WARN)
end

function M.edit(id)
	id = vim.trim(id or "")

	if id == "" then
		vim.notify("PostillaEdit requires a comment id, for example R1", vim.log.levels.WARN)
		return
	end

	for _, comment in ipairs(state.comments) do
		if comment.id == id then
			ui.open_comment_window(comment, function(updated_comment)
				comment.comment = updated_comment
				markers.refresh(comment, state.namespace)
				save_session()
				vim.notify(string.format("Updated Postilla comment %s", id), vim.log.levels.INFO)
			end, comment.comment, config.comment_window)
			return
		end
	end

	vim.notify(string.format("Postilla comment %s not found", id), vim.log.levels.WARN)
end

function M.abort()
	if not state.active then
		vim.notify("No active Postilla session", vim.log.levels.INFO)
		return
	end

	reset_state()
	vim.notify("Postilla session aborted", vim.log.levels.INFO)
end

return M
