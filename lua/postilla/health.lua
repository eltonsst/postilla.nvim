local M = {}

local function has_clipboard()
	return vim.fn.has("clipboard") == 1
end

function M.check()
	vim.health.start("postilla.nvim")

	if vim.fn.has("nvim-0.10") == 1 then
		vim.health.ok("Neovim 0.10+")
	else
		vim.health.error("Neovim 0.10+ is required")
	end

	if vim.fn.executable("git") == 1 then
		vim.health.ok("git executable found")
	else
		vim.health.warn("git executable not found", {
			"Project-relative paths will fall back to Neovim's current working directory.",
		})
	end

	if has_clipboard() then
		vim.health.ok("clipboard provider available")
	else
		vim.health.warn("clipboard provider not available", {
			":PostillaDone writes the prompt to .local-review/last-review.md even when clipboard copy is unavailable.",
			"Run :checkhealth provider.clipboard for system clipboard setup details.",
		})
	end
end

return M
