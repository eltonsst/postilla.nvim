vim.api.nvim_create_user_command("PostillaStart", function()
	require("postilla").start()
end, {})

vim.api.nvim_create_user_command("PostillaComment", function(opts)
	if opts.range > 0 then
		require("postilla").comment(opts.line1, opts.line2)
	else
		require("postilla").comment()
	end
end, { range = true })

vim.api.nvim_create_user_command("PostillaDone", function()
	require("postilla").done()
end, {})

vim.api.nvim_create_user_command("PostillaAbort", function()
	require("postilla").abort()
end, {})

vim.api.nvim_create_user_command("PostillaStatus", function()
	require("postilla").status()
end, {})

vim.api.nvim_create_user_command("PostillaList", function()
	require("postilla").list()
end, {})

vim.api.nvim_create_user_command("PostillaDelete", function(opts)
	require("postilla").delete(opts.args)
end, {
	nargs = 1,
})

vim.api.nvim_create_user_command("PostillaEdit", function(opts)
	require("postilla").edit(opts.args)
end, {
	nargs = 1,
})
