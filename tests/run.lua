local tests = {}

local function test(name, fn)
	table.insert(tests, { name = name, fn = fn })
end

local function fail(message)
	error(message, 2)
end

local function assert_equal(expected, actual)
	if actual ~= expected then
		fail(string.format("expected %q, got %q", expected, actual))
	end
end

local function assert_true(value, message)
	if not value then
		fail(message or "expected value to be truthy")
	end
end

test("formats virtual text with a compact preview", function()
	local markers = require("postilla.markers")
	local label = markers.format_virt_text("R1", "> Consider extracting this helper because it is long")

	assert_equal("💬 R1. Consider extracting this helpe...", label)
end)

test("formats multiline virtual text with an ellipsis", function()
	local markers = require("postilla.markers")
	local label = markers.format_virt_text("R2", "First line\nSecond line")

	assert_equal("💬 R2. First line...", label)
end)

test("refreshes an existing marker in place", function()
	local markers = require("postilla.markers")
	local namespace = vim.api.nvim_create_namespace("postilla-test")
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "target" })

	local comment = {
		id = "R1",
		bufnr = bufnr,
		line = 1,
		comment = "old text",
	}

	comment.extmark_id = markers.place(comment, namespace)
	comment.comment = "new text"
	markers.refresh(comment, namespace)

	local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
	assert_equal(1, #extmarks)
	assert_equal(comment.extmark_id, extmarks[1][1])
	assert_equal("💬 R1. new text", extmarks[1][4].virt_text[1][1])
end)

test("builds a compact prompt with comments and targets", function()
	local prompt = require("postilla.prompt")
	local rendered = prompt.build({
		{
			id = "R1",
			file = "lua/example.lua",
			line = 10,
			comment = "Please simplify this",
			target = "local value = call()",
			context_before = { "local function example()" },
			context_after = { "end" },
		},
	})

	assert_equal(
		"Address these local review comments.\n"
			.. "\n"
			.. "- R1 `lua/example.lua:10`\n"
			.. "  Target: `local value = call()`\n"
			.. "  Comment: Please simplify this\n"
			.. "\n",
		rendered
	)
end)

test("trims targets and escapes backticks in the compact prompt", function()
	local prompt = require("postilla.prompt")
	local rendered = prompt.build({
		{
			id = "R1",
			file = "lua/example.lua",
			line = 10,
			comment = "Use `value` here",
			target = "\tlocal value = `call`()",
			context_before = {},
			context_after = {},
		},
	})

	assert_true(rendered:find("  Target: `local value = \\`call\\`()", 1, true) ~= nil)
	assert_true(rendered:find("  Comment: Use \\`value\\` here", 1, true) ~= nil)
end)

test("quotes multiline comments in the compact prompt", function()
	local prompt = require("postilla.prompt")
	local rendered = prompt.build({
		{
			id = "R1",
			file = "lua/example.lua",
			line = 10,
			comment = "Please simplify this\nAnd keep the name",
			target = "local value = call()",
			context_before = {},
			context_after = {},
		},
	})

	assert_true(rendered:find("  Comment:", 1, true) ~= nil)
	assert_true(rendered:find("  > Please simplify this", 1, true) ~= nil)
	assert_true(rendered:find("  > And keep the name", 1, true) ~= nil)
end)

test("serializes comments without runtime fields", function()
	local session = require("postilla.session")
	local serialized = session.serializable_comments({
		{
			id = "R1",
			bufnr = 7,
			extmark_id = 11,
			root = "/tmp/project",
			file = "lua/example.lua",
			line = 3,
			target = "target",
			context_before = { "before" },
			context_after = { "after" },
			comment = "comment",
		},
	})

	assert_equal(1, #serialized)
	assert_equal(nil, serialized[1].bufnr)
	assert_equal(nil, serialized[1].extmark_id)
	assert_equal("R1", serialized[1].id)
	assert_equal("lua/example.lua", serialized[1].file)
end)

test("returns project-relative paths", function()
	local paths = require("postilla.paths")
	local root = vim.fs.normalize("/tmp/postilla-root")
	local file = vim.fs.joinpath(root, "lua", "example.lua")

	assert_equal("lua/example.lua", paths.relative_path(root, file))
	assert_equal("[No Name]", paths.relative_path(root, ""))
end)

local failures = {}

for _, item in ipairs(tests) do
	local ok, err = pcall(item.fn)
	if ok then
		print("PASS " .. item.name)
	else
		table.insert(failures, "FAIL " .. item.name .. "\n" .. err)
	end
end

if #failures > 0 then
	print(table.concat(failures, "\n\n"))
	vim.cmd.cquit(1)
end

print(string.format("postilla.nvim tests: %d passed", #tests))
