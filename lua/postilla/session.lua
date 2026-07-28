local storage = require("postilla.storage")

local M = {}

function M.path(root, state_root)
	return storage.session_path(root, state_root)
end

function M.serializable_comments(comments)
	local serialized = {}

	for _, comment in ipairs(comments) do
		table.insert(serialized, {
			id = comment.id,
			root = comment.root,
			file = comment.file,
			line = comment.line,
			start_line = comment.start_line or comment.line,
			end_line = comment.end_line,
			change_type = comment.change_type or " ",
			scope = comment.scope or "line",
			target = comment.target,
			context_before = comment.context_before,
			context_after = comment.context_after,
			comment = comment.comment,
		})
	end

	return serialized
end

function M.save(state)
	if not state.root or #state.comments == 0 then
		return
	end

	local path = M.path(state.root)
	local data = {
		version = 2,
		root = state.root,
		next_id = state.next_id,
		comments = M.serializable_comments(state.comments),
	}

	local saved, save_error = storage.write_json(path, data)
	if not saved then
		vim.notify(string.format("Could not save Postilla session: %s", save_error), vim.log.levels.ERROR)
	end

	return saved
end

function M.delete(root)
	if not root then
		return
	end

	local path = M.path(root)

	if vim.fn.filereadable(path) == 1 then
		vim.fn.delete(path)
	end
end

function M.buffer_for_file(root, file)
	local path = vim.fs.joinpath(root, file)

	if vim.fn.filereadable(path) ~= 1 then
		return nil
	end

	local bufnr = vim.fn.bufadd(path)
	vim.fn.bufload(bufnr)

	return bufnr
end

function M.load(root, state, restore_extmark)
	local migration, migration_error = storage.migrate_legacy(root)
	if migration_error then
		vim.notify(string.format("Postilla state migration warning: %s", migration_error), vim.log.levels.WARN)
	end
	if migration.migrated then
		vim.notify(string.format("Migrated legacy review state to %s", storage.project_dir(root)), vim.log.levels.INFO)
	end

	local path = M.path(root)

	if vim.fn.filereadable(path) ~= 1 then
		return false
	end

	local lines = vim.fn.readfile(path)
	local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))

	if not ok or type(data) ~= "table" or type(data.comments) ~= "table" then
		vim.notify("Could not restore Postilla session: invalid session file", vim.log.levels.WARN)
		return false
	end

	state.root = root
	state.next_id = data.next_id or 1
	state.comments = {}
	state.buffers = {}

	for _, saved_comment in ipairs(data.comments) do
		local comment = {
			id = saved_comment.id,
			root = saved_comment.root or root,
			file = saved_comment.file,
			line = saved_comment.start_line or saved_comment.line,
			start_line = saved_comment.start_line or saved_comment.line,
			end_line = saved_comment.end_line,
			change_type = saved_comment.change_type or " ",
			scope = saved_comment.scope or "line",
			target = saved_comment.target,
			context_before = saved_comment.context_before or {},
			context_after = saved_comment.context_after or {},
			comment = saved_comment.comment or "",
		}

		comment.bufnr = M.buffer_for_file(comment.root, comment.file)
		restore_extmark(comment)
		table.insert(state.comments, comment)
	end

	return #state.comments > 0
end

return M
