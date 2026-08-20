local M = {}

local function target_lines(comment)
	if comment.target == nil then
		return nil
	end
	return vim.split(comment.target, "\n", { plain = true })
end

local function set_location(comment, first_line, last_line)
	comment.line = first_line
	comment.start_line = first_line
	comment.end_line = last_line > first_line and last_line or nil
	comment.scope = last_line > first_line and "range" or "line"
end

local function matches_at(lines, target, first_line)
	if first_line < 1 or first_line + #target - 1 > #lines then
		return false
	end

	for index, expected in ipairs(target) do
		if lines[first_line + index - 1] ~= expected then
			return false
		end
	end

	return true
end

local function context_score(lines, comment, first_line, last_line)
	local score = 0
	local before = comment.context_before or {}
	local after = comment.context_after or {}

	for offset = 1, #before do
		local expected = before[#before - offset + 1]
		if lines[first_line - offset] == expected then
			score = score + 1
		else
			break
		end
	end

	for offset, expected in ipairs(after) do
		if lines[last_line + offset] == expected then
			score = score + 1
		else
			break
		end
	end

	return score
end

function M.fingerprint(target)
	return vim.fn.sha256(target or "")
end

function M.resolve(comment)
	if not comment.bufnr or not vim.api.nvim_buf_is_valid(comment.bufnr) then
		comment.stale = true
		comment.stale_reason = "file is missing"
		return false
	end

	local target = target_lines(comment)
	if not target then
		comment.stale = false
		comment.stale_reason = nil
		return true
	end
	if comment.fingerprint and comment.fingerprint ~= M.fingerprint(comment.target) then
		comment.stale = true
		comment.stale_reason = "saved target fingerprint is invalid"
		return false
	end

	local lines = vim.api.nvim_buf_get_lines(comment.bufnr, 0, -1, false)
	local saved_start = comment.start_line or comment.line or 1
	local saved_end = saved_start + #target - 1

	if matches_at(lines, target, saved_start) then
		set_location(comment, saved_start, saved_end)
		comment.stale = false
		comment.stale_reason = nil
		return true
	end

	local candidates = {}
	for first_line = 1, #lines - #target + 1 do
		if matches_at(lines, target, first_line) then
			local last_line = first_line + #target - 1
			table.insert(candidates, {
				first_line = first_line,
				last_line = last_line,
				score = context_score(lines, comment, first_line, last_line),
			})
		end
	end

	if #candidates == 1 then
		set_location(comment, candidates[1].first_line, candidates[1].last_line)
		comment.stale = false
		comment.stale_reason = nil
		comment.relocated = true
		return true
	end

	if #candidates > 1 then
		table.sort(candidates, function(left, right)
			return left.score > right.score
		end)
		if candidates[1].score > candidates[2].score then
			set_location(comment, candidates[1].first_line, candidates[1].last_line)
			comment.stale = false
			comment.stale_reason = nil
			comment.relocated = true
			return true
		end
	end

	comment.stale = true
	comment.stale_reason = #candidates == 0 and "reviewed text changed" or "reviewed text is ambiguous"
	return false
end

function M.place(comment, namespace)
	if not comment.bufnr or not vim.api.nvim_buf_is_valid(comment.bufnr) then
		return nil
	end

	local line_count = vim.api.nvim_buf_line_count(comment.bufnr)
	local first_line = math.min(math.max(comment.start_line or comment.line or 1, 1), line_count)
	local last_line = math.min(math.max(comment.end_line or first_line, first_line), line_count)

	comment.anchor_id = vim.api.nvim_buf_set_extmark(comment.bufnr, namespace, first_line - 1, 0, {
		id = comment.anchor_id,
		end_row = last_line,
		end_col = 0,
		right_gravity = false,
		end_right_gravity = true,
	})

	return comment.anchor_id
end

function M.sync(comment, namespace)
	if not comment.anchor_id or not comment.bufnr or not vim.api.nvim_buf_is_valid(comment.bufnr) then
		return false
	end

	local position = vim.api.nvim_buf_get_extmark_by_id(comment.bufnr, namespace, comment.anchor_id, { details = true })
	if #position == 0 then
		return false
	end

	local first_line = position[1] + 1
	local details = position[3] or {}
	local last_line = math.max(first_line, details.end_row or first_line)
	set_location(comment, first_line, last_line)

	local target = target_lines(comment)
	if target then
		local lines = vim.api.nvim_buf_get_lines(comment.bufnr, 0, -1, false)
		local expected_last_line = first_line + #target - 1
		if last_line ~= expected_last_line or not matches_at(lines, target, first_line) then
			if M.resolve(comment) then
				M.place(comment, namespace)
			end
			return true
		end
	end

	comment.stale = false
	comment.stale_reason = nil
	return true
end

function M.delete(comment, namespace)
	if comment.anchor_id and comment.bufnr and vim.api.nvim_buf_is_valid(comment.bufnr) then
		pcall(vim.api.nvim_buf_del_extmark, comment.bufnr, namespace, comment.anchor_id)
	end
	comment.anchor_id = nil
end

return M
