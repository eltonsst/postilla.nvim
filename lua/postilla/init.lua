local anchors = require("postilla.anchors")
local location = require("postilla.location")
local markers = require("postilla.markers")
local navigation = require("postilla.navigation")
local paths = require("postilla.paths")
local revdiff = require("postilla.revdiff")
local session = require("postilla.session")
local state = require("postilla.state")
local storage = require("postilla.storage")
local ui = require("postilla.ui")

local M = {}

local config = {
	context_lines = 5,
	keymap = nil,
	next_keymap = nil,
	previous_keymap = nil,
	marker = {
		style = "virtual_line",
	},
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
	anchors.resolve(comment)
	anchors.place(comment, state.anchor_namespace)
	local extmark_id = markers.place(comment, state.namespace, config.marker)
	if extmark_id then
		comment.extmark_id = extmark_id
		state.buffers[comment.bufnr] = true
	end
end

local function save_session()
	for _, comment in ipairs(state.comments) do
		anchors.sync(comment, state.anchor_namespace)
	end
	session.save(state)
end

local function sync_comments()
	for _, comment in ipairs(state.comments) do
		local previous_start = comment.start_line or comment.line
		local previous_end = comment.end_line
		local previous_stale = comment.stale
		if
			anchors.sync(comment, state.anchor_namespace)
			and (
				previous_start ~= comment.start_line
				or previous_end ~= comment.end_line
				or previous_stale ~= comment.stale
			)
		then
			markers.refresh(comment, state.namespace, config.marker)
		end
	end
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
		fingerprint = review_location.fingerprint,
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
			vim.api.nvim_buf_clear_namespace(bufnr, state.anchor_namespace, 0, -1)
		end
	end

	state.active = false
	state.comments = {}
	state.buffers = {}
	state.next_id = 1
	state.current_comment_id = nil
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
	if config.next_keymap then
		vim.keymap.set("n", config.next_keymap, M.next, { desc = "Next Postilla comment" })
	end
	if config.previous_keymap then
		vim.keymap.set("n", config.previous_keymap, M.previous, { desc = "Previous Postilla comment" })
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
	local window_options = vim.tbl_deep_extend("force", config.comment_window, {
		comment_count = #state.comments,
	})
	ui.open_comment_window(review_location, function(comment)
		local stored = add_comment(review_location, comment)
		vim.notify(
			string.format("Stored review comment %s for %s:%s", stored.id, stored.file, line_label(stored)),
			vim.log.levels.INFO
		)
	end, nil, window_options)
end

local function stale_comment_ids()
	sync_comments()
	local ids = {}
	for _, comment in ipairs(state.comments) do
		if comment.stale then
			table.insert(ids, comment.id)
		end
	end
	return ids
end

local function review_output()
	local stale_ids = stale_comment_ids()
	if #stale_ids > 0 then
		vim.notify(
			string.format(
				"Cannot export stale Postilla comments: %s. Delete and recreate them.",
				table.concat(stale_ids, ", ")
			),
			vim.log.levels.ERROR
		)
		return nil
	end
	return revdiff.build(state.comments)
end

local function export_review(clear_session)
	if not state.active then
		vim.notify("No active Postilla session", vim.log.levels.INFO)
		return false
	end

	if #state.comments == 0 then
		if clear_session then
			reset_state()
		end
		vim.notify("No Postilla comments to export", vim.log.levels.INFO)
		return false
	end

	local output = review_output()
	if not output then
		return false
	end
	local saved_path, save_error = revdiff.save(output, state.comments[1].root)
	if not saved_path then
		vim.notify(string.format("Could not save Postilla output: %s", save_error), vim.log.levels.ERROR)
		return false
	end
	local comment_count = #state.comments

	vim.fn.setreg("+", output)
	if clear_session then
		reset_state()
	else
		save_session()
	end

	vim.notify(
		string.format(
			"Copied %d review comment(s), saved %s%s",
			comment_count,
			saved_path,
			clear_session and ", and finished the session" or ""
		),
		vim.log.levels.INFO
	)
	return true
end

function M.export()
	return export_review(false)
end

function M.done()
	return export_review(true)
end

function M.status()
	sync_comments()
	local session_status = state.active and "active" or "inactive"
	local message = string.format("Postilla session: %s\nComments: %d", session_status, #state.comments)
	local stale_count = 0
	for _, comment in ipairs(state.comments) do
		if comment.stale then
			stale_count = stale_count + 1
		end
	end
	if stale_count > 0 then
		message = message .. string.format("\nStale: %d", stale_count)
	end
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

	sync_comments()
	local items = {}

	for _, comment in ipairs(state.comments) do
		local first_line = vim.split(comment.comment, "\n", { plain = true })[1] or ""
		local range = comment.end_line and string.format(" [%s]", line_label(comment)) or ""
		local stale = comment.stale and " [stale]" or ""

		table.insert(items, {
			bufnr = comment.bufnr,
			lnum = comment.start_line or comment.line,
			col = 1,
			text = string.format("%s%s%s: %s", comment.id, range, stale, first_line),
		})
	end

	vim.fn.setqflist({}, " ", {
		title = "Postilla Comments",
		items = items,
	})
	vim.cmd.copen()
end

local function jump_to_comment(comment)
	if not comment.bufnr or not vim.api.nvim_buf_is_valid(comment.bufnr) then
		comment.bufnr = session.buffer_for_file(comment.root, comment.file)
	end
	if not comment.bufnr then
		vim.notify(string.format("Could not open %s for comment %s", comment.file, comment.id), vim.log.levels.WARN)
		return false
	end

	vim.api.nvim_set_current_buf(comment.bufnr)
	vim.api.nvim_win_set_cursor(0, { comment.start_line or comment.line, 0 })
	vim.cmd("normal! zz")
	state.current_comment_id = comment.id
	return true
end

function M.preview()
	if #state.comments == 0 then
		vim.notify("No Postilla comments to preview", vim.log.levels.INFO)
		return
	end

	local output = review_output()
	if not output then
		return
	end
	local _, line_map = revdiff.build_index(state.comments)
	ui.open_preview(output, line_map, function()
		vim.fn.setreg("+", output)
		vim.notify(string.format("Copied %d Postilla comment(s)", #state.comments), vim.log.levels.INFO)
	end, jump_to_comment)
end

local function navigate(direction)
	if #state.comments == 0 then
		vim.notify("No Postilla comments", vim.log.levels.INFO)
		return
	end

	sync_comments()
	local bufnr = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local file = paths.relative_path(state.root or vim.fn.getcwd(), vim.api.nvim_buf_get_name(bufnr))
	local comment = navigation.pick(state.comments, {
		id = state.current_comment_id,
		bufnr = bufnr,
		file = file,
		line = line,
	}, direction)

	if not comment then
		return
	end

	if not jump_to_comment(comment) then
		return
	end
	vim.notify(string.format("%s at %s:%s", comment.id, comment.file, line_label(comment)), vim.log.levels.INFO)
end

function M.next()
	navigate(1)
end

function M.previous()
	navigate(-1)
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
			anchors.delete(comment, state.anchor_namespace)

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
			anchors.sync(comment, state.anchor_namespace)
			local window_options = vim.tbl_deep_extend("force", config.comment_window, {
				comment_count = #state.comments,
			})
			ui.open_comment_window(comment, function(updated_comment)
				comment.comment = updated_comment
				markers.refresh(comment, state.namespace, config.marker)
				save_session()
				vim.notify(string.format("Updated Postilla comment %s", id), vim.log.levels.INFO)
			end, comment.comment, window_options)
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
