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

local function temporary_directory(label)
	local path = vim.fn.tempname() .. "-" .. label
	vim.fn.mkdir(path, "p")
	return vim.fs.normalize(path)
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

test("builds a RevDiff context annotation from a line comment", function()
	local revdiff = require("postilla.revdiff")
	local rendered = revdiff.build({
		{
			id = "R1",
			file = "lua/example.lua",
			line = 10,
			comment = "Please simplify this",
		},
	})

	assert_equal("## lua/example.lua:10 ( )\nPlease simplify this\n", rendered)
end)

test("sorts RevDiff records and formats file, line, and range annotations", function()
	local revdiff = require("postilla.revdiff")
	local rendered = revdiff.build({
		{
			file = "zeta.lua",
			start_line = 8,
			change_type = "-",
			comment = "Keep this validation.",
		},
		{
			file = "alpha.lua",
			start_line = 12,
			end_line = 18,
			change_type = "+",
			scope = "range",
			comment = "Reduce the nesting.",
		},
		{
			file = "alpha.lua",
			scope = "file",
			comment = "Split this module.",
		},
	})

	assert_equal(
		"## alpha.lua (file-level)\n"
			.. "Split this module.\n"
			.. "\n"
			.. "## alpha.lua:12-18 (+)\n"
			.. "Reduce the nesting.\n"
			.. "\n"
			.. "## zeta.lua:8 (-)\n"
			.. "Keep this validation.\n",
		rendered
	)
end)

test("preserves multiline markdown and escapes RevDiff-like body headers", function()
	local revdiff = require("postilla.revdiff")
	local rendered = revdiff.build({
		{
			file = "lua/example.lua",
			start_line = 4,
			change_type = "+",
			comment = "First paragraph\n## not a record\n  ## also not a record\n### safe subheading",
		},
	})

	assert_equal(
		"## lua/example.lua:4 (+)\n"
			.. "First paragraph\n"
			.. " ## not a record\n"
			.. "   ## also not a record\n"
			.. "### safe subheading\n",
		rendered
	)
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
			start_line = 3,
			end_line = 5,
			change_type = "+",
			scope = "range",
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
	assert_equal(3, serialized[1].start_line)
	assert_equal(5, serialized[1].end_line)
	assert_equal("+", serialized[1].change_type)
	assert_equal("range", serialized[1].scope)
end)

test("stores project state outside the project root", function()
	local session = require("postilla.session")
	local storage = require("postilla.storage")
	local project_root = vim.fs.normalize("/tmp/projects/example")
	local state_root = vim.fs.normalize("/tmp/postilla-state")
	local other_project = vim.fs.normalize("/tmp/other/example")
	local path = session.path(project_root, state_root)

	assert_true(vim.startswith(path, state_root .. "/"))
	assert_true(not vim.startswith(path, project_root .. "/"))
	assert_true(storage.project_key(project_root) ~= storage.project_key(other_project))
end)

test("saves sessions and output below the configured state directory", function()
	local revdiff = require("postilla.revdiff")
	local session = require("postilla.session")
	local storage = require("postilla.storage")
	local project_root = temporary_directory("postilla-save-project")
	local state_root = temporary_directory("postilla-save-state")

	storage.setup({ state_dir = state_root })
	local saved = session.save({
		root = project_root,
		next_id = 2,
		comments = {
			{
				id = "R1",
				root = project_root,
				file = "lua/example.lua",
				line = 3,
				target = "return value",
				context_before = {},
				context_after = {},
				comment = "Keep this",
			},
		},
	})
	local review_path, review_error = revdiff.save("review output\n", project_root)

	assert_true(saved)
	assert_equal(nil, review_error)
	assert_true(vim.startswith(session.path(project_root), state_root .. "/"))
	assert_true(vim.startswith(review_path, state_root .. "/"))
	assert_equal(0, vim.fn.isdirectory(vim.fs.joinpath(project_root, ".local-review")))

	storage.setup()
	vim.fn.delete(project_root, "rf")
	vim.fn.delete(state_root, "rf")
end)

test("migrates valid legacy state and removes the empty legacy directory", function()
	local storage = require("postilla.storage")
	local project_root = temporary_directory("postilla-project")
	local state_root = temporary_directory("postilla-state")
	local legacy_dir = vim.fs.joinpath(project_root, ".local-review")
	local legacy_session = vim.fs.joinpath(legacy_dir, "session.json")
	local legacy_review = vim.fs.joinpath(legacy_dir, "last-review.md")

	vim.fn.mkdir(legacy_dir, "p")
	vim.fn.writefile({
		vim.json.encode({
			version = 1,
			next_id = 2,
			comments = {
				{
					id = "R1",
					file = "lua/example.lua",
					line = 4,
					comment = "Keep this validation",
				},
			},
		}),
	}, legacy_session)
	vim.fn.writefile({ "legacy output" }, legacy_review)

	local migrated, migration_error = storage.migrate_legacy(project_root, state_root)

	assert_equal(nil, migration_error)
	assert_true(migrated.session)
	assert_true(migrated.last_review)
	assert_equal(1, vim.fn.filereadable(storage.session_path(project_root, state_root)))
	assert_equal(1, vim.fn.filereadable(storage.last_review_path(project_root, state_root)))
	assert_equal(0, vim.fn.filereadable(legacy_session))
	assert_equal(0, vim.fn.isdirectory(legacy_dir))

	vim.fn.delete(project_root, "rf")
	vim.fn.delete(state_root, "rf")
end)

test("preserves invalid legacy session data", function()
	local storage = require("postilla.storage")
	local project_root = temporary_directory("postilla-invalid-project")
	local state_root = temporary_directory("postilla-invalid-state")
	local legacy_dir = vim.fs.joinpath(project_root, ".local-review")
	local legacy_session = vim.fs.joinpath(legacy_dir, "session.json")

	vim.fn.mkdir(legacy_dir, "p")
	vim.fn.writefile({ "{ invalid" }, legacy_session)

	local migrated, migration_error = storage.migrate_legacy(project_root, state_root)

	assert_true(not migrated.session)
	assert_true(migration_error ~= nil)
	assert_equal(1, vim.fn.filereadable(legacy_session))
	assert_equal(0, vim.fn.filereadable(storage.session_path(project_root, state_root)))

	vim.fn.delete(project_root, "rf")
	vim.fn.delete(state_root, "rf")
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
