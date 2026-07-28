local M = {}

function M.path(root)
	return vim.fs.joinpath(root or vim.fn.getcwd(), ".local-review", "session.json")
end

function M.serializable_comments(comments)
	local serialized = {}

	for _, comment in ipairs(comments) do
		table.insert(serialized, {
			id = comment.id,
			root = comment.root,
			file = comment.file,
			line = comment.line,
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
		version = 1,
		next_id = state.next_id,
		comments = M.serializable_comments(state.comments),
	}

	vim.fn.mkdir(vim.fs.dirname(path), "p")
	vim.fn.writefile({ vim.json.encode(data) }, path)
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
			line = saved_comment.line,
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
