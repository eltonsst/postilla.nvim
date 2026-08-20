return {
	active = false,
	comments = {},
	buffers = {},
	next_id = 1,
	current_comment_id = nil,
	namespace = vim.api.nvim_create_namespace("postilla"),
	anchor_namespace = vim.api.nvim_create_namespace("postilla-anchors"),
	root = nil,
}
