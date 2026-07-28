local M = {}

local function inline_code(text)
	return (vim.trim(text or ""):gsub("`", "\\`"))
end

function M.build(comments)
	local lines = {
		"Address these local review comments.",
		"",
	}

	for _, comment in ipairs(comments) do
		table.insert(lines, string.format("- %s `%s:%d`", comment.id, comment.file, comment.line))
		table.insert(lines, string.format("  Target: `%s`", inline_code(comment.target)))

		local comment_lines = vim.split(comment.comment, "\n", { plain = true })
		if #comment_lines <= 1 then
			table.insert(lines, "  Comment: " .. inline_code(comment_lines[1] or ""))
		else
			table.insert(lines, "  Comment:")
			for _, comment_line in ipairs(comment_lines) do
				table.insert(lines, "  > " .. comment_line)
			end
		end

		table.insert(lines, "")
	end

	return table.concat(lines, "\n") .. "\n"
end

function M.save(review_prompt, root)
	local dir = vim.fs.joinpath(root or vim.fn.getcwd(), ".local-review")
	local path = vim.fs.joinpath(dir, "last-review.md")

	vim.fn.mkdir(dir, "p")
	vim.fn.writefile(vim.split(review_prompt, "\n", { plain = true }), path)

	return path
end

return M
