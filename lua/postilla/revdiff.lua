local storage = require("postilla.storage")

local M = {}

local function escape_header_lines(body)
	local lines = vim.split(body or "", "\n", { plain = true })

	for index, line in ipairs(lines) do
		if vim.startswith(line:gsub("^%s*", ""), "## ") then
			lines[index] = " " .. line
		end
	end

	return table.concat(lines, "\n")
end

local function normalized_type(comment)
	local change_type = comment.change_type or " "
	if change_type ~= "+" and change_type ~= "-" and change_type ~= " " then
		return " "
	end
	return change_type
end

local function start_line(comment)
	return comment.start_line or comment.line or 0
end

local function is_file_level(comment)
	return comment.scope == "file" or start_line(comment) == 0
end

local function sorted_comments(comments)
	local result = {}

	for index, comment in ipairs(comments) do
		table.insert(result, {
			comment = comment,
			index = index,
		})
	end

	table.sort(result, function(left, right)
		local left_comment = left.comment
		local right_comment = right.comment

		if left_comment.file ~= right_comment.file then
			return left_comment.file < right_comment.file
		end

		local left_line = is_file_level(left_comment) and 0 or start_line(left_comment)
		local right_line = is_file_level(right_comment) and 0 or start_line(right_comment)
		if left_line ~= right_line then
			return left_line < right_line
		end

		return left.index < right.index
	end)

	return result
end

local function header(comment)
	if is_file_level(comment) then
		return string.format("## %s (file-level)", comment.file)
	end

	local first_line = start_line(comment)
	local change_type = normalized_type(comment)
	if comment.end_line and comment.end_line > first_line then
		return string.format("## %s:%d-%d (%s)", comment.file, first_line, comment.end_line, change_type)
	end

	return string.format("## %s:%d (%s)", comment.file, first_line, change_type)
end

function M.build(comments)
	local records = {}

	for _, item in ipairs(sorted_comments(comments)) do
		local comment = item.comment
		table.insert(records, string.format("%s\n%s", header(comment), escape_header_lines(comment.comment)))
	end

	if #records == 0 then
		return ""
	end

	return table.concat(records, "\n\n") .. "\n"
end

function M.save(review_output, root)
	local path = storage.last_review_path(root)
	local saved, save_error = storage.write(path, review_output)

	if not saved then
		return nil, save_error
	end

	return path
end

return M
