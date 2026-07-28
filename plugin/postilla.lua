vim.api.nvim_create_user_command("PostillaStart", function()
	require("postilla").start()
end, {})

vim.api.nvim_create_user_command("PostillaComment", function()
	require("postilla").comment()
end, {})

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
