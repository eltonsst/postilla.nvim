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

test("includes the selected range in virtual text", function()
	local markers = require("postilla.markers")
	local label = markers.format_virt_text("R3", "Review this block", 4, 7)

	assert_equal("💬 R3 [4-7]. Review this block", label)
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

test("places a range comment marker on the final selected line", function()
	local markers = require("postilla.markers")
	local namespace = vim.api.nvim_create_namespace("postilla-range-marker-test")
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three", "four", "five" })

	markers.place({
		id = "R1",
		bufnr = bufnr,
		line = 2,
		start_line = 2,
		end_line = 4,
		comment = "Review this block",
	}, namespace)

	local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
	assert_equal(1, #extmarks)
	assert_equal(3, extmarks[1][2])
	assert_equal("💬 R1 [2-4]. Review this block", extmarks[1][4].virt_text[1][1])
end)

test("captures a normalized line range with surrounding context", function()
	local location = require("postilla.location")
	local original_buf = vim.api.nvim_get_current_buf()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three", "four", "five", "six" })

	local captured = location.capture(1, 5, 3)

	assert_equal(3, captured.line)
	assert_equal(3, captured.start_line)
	assert_equal(5, captured.end_line)
	assert_equal("range", captured.scope)
	assert_equal("three\nfour\nfive", captured.target)
	assert_equal("two", captured.context_before[1])
	assert_equal("six", captured.context_after[1])

	vim.api.nvim_set_current_buf(original_buf)
	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("registers the configured comment keymap in Normal and Visual modes", function()
	local postilla = require("postilla")
	local keymap = "<leader>rC"
	local original_comment = postilla.comment
	local captured_start
	local captured_end

	postilla.setup({ keymap = keymap })
	local normal_mapping = vim.fn.maparg(keymap, "n", false, true)
	local visual_mapping = vim.fn.maparg(keymap, "x", false, true)
	assert_true(normal_mapping.callback ~= nil, "Normal-mode comment mapping is missing")
	assert_true(visual_mapping.callback ~= nil, "Visual-mode comment mapping is missing")

	local bufnr = vim.api.nvim_get_current_buf()
	vim.bo[bufnr].swapfile = false
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three", "four" })
	vim.bo[bufnr].modified = false
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
	vim.cmd("normal! Vj")

	postilla.comment = function(start_line, end_line)
		captured_start = start_line
		captured_end = end_line
	end
	visual_mapping.callback()
	postilla.comment = original_comment
	vim.api.nvim_feedkeys("\27", "nx", false)

	assert_equal(2, captured_start)
	assert_equal(3, captured_end)
	assert_equal("two", vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1])
	assert_equal("three", vim.api.nvim_buf_get_lines(bufnr, 2, 3, false)[1])
end)

test("creates a range comment from the Visual-mode keymap", function()
	local postilla = require("postilla")
	local revdiff = require("postilla.revdiff")
	local state = require("postilla.state")
	local storage = require("postilla.storage")
	local state_root = temporary_directory("postilla-visual-range-state")
	local keymap = "<leader>rR"
	local bufnr = vim.api.nvim_get_current_buf()

	postilla.setup({ keymap = keymap, state_dir = state_root })
	vim.bo[bufnr].swapfile = false
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three", "four" })
	vim.bo[bufnr].modified = false
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
	vim.cmd("normal! Vj")
	vim.fn.maparg(keymap, "x", false, true).callback()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Review this range" })
	vim.fn.maparg("<C-s>", "i", false, true).callback()

	assert_equal(1, #state.comments)
	assert_equal("range", state.comments[1].scope)
	assert_equal(2, state.comments[1].start_line)
	assert_equal(3, state.comments[1].end_line)
	assert_equal("Review this range", state.comments[1].comment)
	assert_equal("## [No Name]:2-3 ( )\nReview this range\n", revdiff.build(state.comments))
	assert_equal("n", vim.api.nvim_get_mode().mode)
	assert_equal("two", vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1])
	assert_equal("three", vim.api.nvim_buf_get_lines(bufnr, 2, 3, false)[1])

	postilla.abort()
	storage.setup()
	vim.fn.delete(state_root, "rf")
end)

test("forwards an explicit Ex range to PostillaComment", function()
	local postilla = require("postilla")
	local original_comment = postilla.comment
	local captured_start
	local captured_end

	vim.cmd("runtime plugin/postilla.lua")
	postilla.comment = function(start_line, end_line)
		captured_start = start_line
		captured_end = end_line
	end
	vim.cmd("2,4PostillaComment")
	postilla.comment = original_comment

	assert_equal(2, captured_start)
	assert_equal(4, captured_end)
end)

test("returns to Normal mode after saving a comment", function()
	local ui = require("postilla.ui")
	local original_win = vim.api.nvim_get_current_win()
	local original_buf = vim.api.nvim_get_current_buf()
	local saved_comment

	vim.bo[original_buf].swapfile = false
	vim.api.nvim_buf_set_lines(original_buf, 0, -1, false, { "one", "two", "three", "four" })
	vim.bo[original_buf].modified = false
	vim.api.nvim_win_set_cursor(original_win, { 3, 0 })
	local original_view = vim.api.nvim_win_call(original_win, vim.fn.winsaveview)
	local original_matches = vim.api.nvim_win_call(original_win, vim.fn.getmatches)

	ui.open_comment_window({ file = "lua/example.lua", line = 3, bufnr = original_buf }, function(comment)
		saved_comment = comment
	end)
	local comment_win = vim.api.nvim_get_current_win()
	assert_true(comment_win ~= original_win, "comment editor did not open in a separate window")
	assert_equal("", vim.api.nvim_win_get_config(comment_win).relative)
	assert_true(vim.wo[comment_win].winfixheight, "comment split height is not fixed")
	local highlighted_matches = vim.api.nvim_win_call(original_win, vim.fn.getmatches)
	assert_equal(#original_matches + 1, #highlighted_matches)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Please simplify this" })

	local save_mapping = vim.fn.maparg("<C-s>", "i", false, true)
	local original_stopinsert = vim.cmd.stopinsert
	local stopped_insert = false
	vim.cmd.stopinsert = function()
		stopped_insert = true
		original_stopinsert()
	end

	local ok, err = pcall(save_mapping.callback)
	vim.cmd.stopinsert = original_stopinsert

	assert_true(ok, err)
	assert_true(stopped_insert, "saving did not leave Insert mode")
	assert_equal(original_win, vim.api.nvim_get_current_win())
	local restored_view = vim.api.nvim_win_call(original_win, vim.fn.winsaveview)
	assert_equal(original_view.lnum, restored_view.lnum)
	assert_equal(original_view.topline, restored_view.topline)
	local restored_matches = vim.api.nvim_win_call(original_win, vim.fn.getmatches)
	assert_equal(#original_matches, #restored_matches)
	assert_equal("Please simplify this", saved_comment)
end)

test("shows and highlights the full range while writing a comment", function()
	local ui = require("postilla.ui")
	local original_win = vim.api.nvim_get_current_win()
	local original_buf = vim.api.nvim_get_current_buf()
	local original_matches = vim.api.nvim_win_call(original_win, vim.fn.getmatches)

	vim.api.nvim_buf_set_lines(original_buf, 0, -1, false, { "one", "two", "three", "four" })
	vim.bo[original_buf].modified = false
	ui.open_comment_window({
		file = "lua/example.lua",
		line = 2,
		start_line = 2,
		end_line = 4,
		bufnr = original_buf,
	}, function() end)

	local comment_win = vim.api.nvim_get_current_win()
	assert_true(vim.wo[comment_win].winbar:find("lua/example.lua:2%-4") ~= nil, "range is missing from the winbar")
	local highlighted_matches = vim.api.nvim_win_call(original_win, vim.fn.getmatches)
	assert_equal(#original_matches + 1, #highlighted_matches)
	assert_true(highlighted_matches[#highlighted_matches].pattern:find("%%>1l") ~= nil)
	assert_true(highlighted_matches[#highlighted_matches].pattern:find("%%<5l") ~= nil)

	local cancel_mapping = vim.fn.maparg("<Esc>", "n", false, true)
	cancel_mapping.callback()
	assert_equal(original_win, vim.api.nvim_get_current_win())
	assert_equal(#original_matches, #vim.api.nvim_win_call(original_win, vim.fn.getmatches))
end)

test("supports the legacy floating comment editor layout", function()
	local ui = require("postilla.ui")
	local original_win = vim.api.nvim_get_current_win()
	local original_buf = vim.api.nvim_get_current_buf()

	ui.open_comment_window({ file = "lua/example.lua", line = 1, bufnr = original_buf }, function() end, nil, {
		layout = "float",
		height = 6,
		width = 40,
	})
	local comment_win = vim.api.nvim_get_current_win()
	assert_equal("editor", vim.api.nvim_win_get_config(comment_win).relative)

	local cancel_mapping = vim.fn.maparg("<Esc>", "n", false, true)
	cancel_mapping.callback()
	assert_equal(original_win, vim.api.nvim_get_current_win())
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
