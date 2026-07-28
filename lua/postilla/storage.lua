local M = {}

local configured_state_dir

local function normalized_root(root)
	local normalized = vim.fs.normalize(root or vim.fn.getcwd())
	return vim.uv.fs_realpath(normalized) or normalized
end

local function safe_basename(root)
	local name = vim.fs.basename(normalized_root(root))
	name = name:gsub("[^%w._-]", "-"):gsub("%-+", "-")

	if name == "" then
		return "project"
	end

	return name
end

local function read_file(path)
	local ok, lines = pcall(vim.fn.readfile, path, "b")
	if not ok then
		return nil, lines
	end

	return table.concat(lines, "\n")
end

local function legacy_dir(root)
	return vim.fs.joinpath(normalized_root(root), ".local-review")
end

local function migrate_file(source, destination, validate)
	if vim.fn.filereadable(source) ~= 1 or vim.fn.filereadable(destination) == 1 then
		return false
	end

	local content, read_error = read_file(source)
	if not content then
		return false, string.format("could not read %s: %s", source, read_error)
	end

	if validate then
		local valid, validation_error = validate(content)
		if not valid then
			return false, validation_error
		end
	end

	local written, write_error = M.write(destination, content)
	if not written then
		return false, write_error
	end

	if vim.fn.delete(source) ~= 0 then
		return true, string.format("migrated %s but could not remove the legacy file", source)
	end

	return true
end

function M.setup(opts)
	configured_state_dir = opts and opts.state_dir or nil
end

function M.root(override)
	return vim.fs.normalize(override or configured_state_dir or vim.fs.joinpath(vim.fn.stdpath("state"), "postilla"))
end

function M.project_key(root)
	local project_root = normalized_root(root)
	local digest = vim.fn.sha256(project_root):sub(1, 12)
	return string.format("%s-%s", safe_basename(project_root), digest)
end

function M.project_dir(root, state_root)
	return vim.fs.joinpath(M.root(state_root), "projects", M.project_key(root))
end

function M.session_path(root, state_root)
	return vim.fs.joinpath(M.project_dir(root, state_root), "session.json")
end

function M.last_review_path(root, state_root)
	return vim.fs.joinpath(M.project_dir(root, state_root), "last-review.md")
end

function M.legacy_session_path(root)
	return vim.fs.joinpath(legacy_dir(root), "session.json")
end

function M.legacy_last_review_path(root)
	return vim.fs.joinpath(legacy_dir(root), "last-review.md")
end

function M.write(path, content)
	local directory = vim.fs.dirname(path)
	vim.fn.mkdir(directory, "p")

	local suffix = string.format("%d-%d", vim.uv.os_getpid(), vim.uv.hrtime())
	local temporary_path = string.format("%s.tmp-%s", path, suffix)
	local lines = vim.split(content, "\n", { plain = true })
	local ok, write_result = pcall(vim.fn.writefile, lines, temporary_path, "b")

	if not ok or write_result ~= 0 then
		vim.fn.delete(temporary_path)
		return nil, string.format("could not write temporary state file for %s", path)
	end

	local renamed, rename_error = vim.uv.fs_rename(temporary_path, path)
	if not renamed then
		vim.fn.delete(temporary_path)
		return nil, string.format("could not replace %s: %s", path, rename_error or "unknown error")
	end

	return true
end

function M.write_json(path, value)
	return M.write(path, vim.json.encode(value))
end

function M.migrate_legacy(root, state_root)
	local result = {
		migrated = false,
		session = false,
		last_review = false,
	}
	local errors = {}

	local session_migrated, session_error = migrate_file(
		M.legacy_session_path(root),
		M.session_path(root, state_root),
		function(content)
			local decoded, data = pcall(vim.json.decode, content)
			if not decoded or type(data) ~= "table" or type(data.comments) ~= "table" then
				return false, "legacy session is not valid Postilla session data"
			end
			return true
		end
	)

	result.session = session_migrated
	result.migrated = result.migrated or session_migrated
	if session_error then
		table.insert(errors, session_error)
	end

	local review_migrated, review_error =
		migrate_file(M.legacy_last_review_path(root), M.last_review_path(root, state_root))

	result.last_review = review_migrated
	result.migrated = result.migrated or review_migrated
	if review_error then
		table.insert(errors, review_error)
	end

	local old_dir = legacy_dir(root)
	if vim.fn.isdirectory(old_dir) == 1 and #vim.fn.readdir(old_dir) == 0 then
		vim.fn.delete(old_dir, "d")
	end

	if #errors > 0 then
		return result, table.concat(errors, "; ")
	end

	return result
end

return M
