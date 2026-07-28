local M = {}

function M.project_root_for(path)
	local start_dir = path ~= "" and vim.fn.fnamemodify(path, ":p:h") or vim.fn.getcwd()
	local result = vim.fn.systemlist({ "git", "-C", start_dir, "rev-parse", "--show-toplevel" })

	if vim.v.shell_error == 0 and result[1] and result[1] ~= "" then
		return result[1]
	end

	return vim.fn.getcwd()
end

function M.relative_path(root, path)
	if path == "" then
		return "[No Name]"
	end

	local normalized_root = vim.fs.normalize(root)
	local normalized_path = vim.fs.normalize(path)
	local root_prefix = normalized_root .. "/"

	if vim.startswith(normalized_path, root_prefix) then
		return normalized_path:sub(#root_prefix + 1)
	end

	return normalized_path
end

return M
