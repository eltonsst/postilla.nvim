local M = {}

local function first_line(comment)
	return comment.start_line or comment.line or 1
end

local function sorted_comments(comments)
	local result = vim.list_extend({}, comments)
	table.sort(result, function(left, right)
		if left.file ~= right.file then
			return left.file < right.file
		end
		if first_line(left) ~= first_line(right) then
			return first_line(left) < first_line(right)
		end
		return (left.id or "") < (right.id or "")
	end)
	return result
end

local function contains(comment, bufnr, line)
	local last_line = comment.end_line or first_line(comment)
	return comment.bufnr == bufnr and line >= first_line(comment) and line <= last_line
end

function M.pick(comments, current, direction)
	if #comments == 0 then
		return nil
	end

	local sorted = sorted_comments(comments)
	local current_index

	if current.id then
		for index, comment in ipairs(sorted) do
			if comment.id == current.id and contains(comment, current.bufnr, current.line) then
				current_index = index
				break
			end
		end
	end

	if not current_index then
		for index, comment in ipairs(sorted) do
			if contains(comment, current.bufnr, current.line) then
				current_index = index
				break
			end
		end
	end

	if current_index then
		return sorted[((current_index - 1 + direction) % #sorted) + 1]
	end

	if direction > 0 then
		for _, comment in ipairs(sorted) do
			if comment.file > current.file or (comment.file == current.file and first_line(comment) > current.line) then
				return comment
			end
		end
		return sorted[1]
	end

	for index = #sorted, 1, -1 do
		local comment = sorted[index]
		if comment.file < current.file or (comment.file == current.file and first_line(comment) < current.line) then
			return comment
		end
	end
	return sorted[#sorted]
end

return M
