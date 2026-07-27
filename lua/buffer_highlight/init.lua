local highlights = require("buffer_highlight.highlights")

local M = {}

M.defaults = {
	focused_bg = nil,
	focused_ctermbg = nil,
	unfocused_bg = nil,
	unfocused_ctermbg = nil,
	interpolation = true,
	enabled = true,
}

M.options = {}

M.setup = function(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})

	for _, key in ipairs({"focused_bg", "unfocused_bg"}) do
		if M.options[key] == "NONE" then
			M.options[key] = nil
		end
	end

	if M.options.enabled == false then
		highlights.clear_windows()
		M._cleanup_autocmds()
		return
	end

	highlights.setup_highlights(M.options)
	highlights.update_windows(M.options)
	M._setup_autocmds()
end

M._setup_autocmds = function()
	if M._autocmd_ids then
		for _, id in ipairs(M._autocmd_ids) do
			pcall(vim.api.nvim_del_autocmd, id)
		end
	end
	M._autocmd_ids = {}

	local group = vim.api.nvim_create_augroup("BufferHighlightWinGroup", { clear = false })

	local id1 = vim.api.nvim_create_autocmd("WinEnter", {
		group = group,
		callback = function()
			highlights.update_windows(M.options)
		end,
	})
	table.insert(M._autocmd_ids, id1)

	local id2 = vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		callback = function()
			highlights.update_windows(M.options)
		end,
	})
	table.insert(M._autocmd_ids, id2)

	local id3 = vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function()
			highlights.update_windows(M.options)
		end,
	})
	table.insert(M._autocmd_ids, id3)

	local id4 = vim.api.nvim_create_autocmd("TabEnter", {
		group = group,
		callback = function()
			highlights.update_windows(M.options)
		end,
	})
	table.insert(M._autocmd_ids, id4)
end

M._cleanup_autocmds = function()
	if M._autocmd_ids then
		for _, id in ipairs(M._autocmd_ids) do
			pcall(vim.api.nvim_del_autocmd, id)
		end
		M._autocmd_ids = nil
	end
	pcall(vim.api.nvim_del_augroup, "BufferHighlightWinGroup")
end

M.toggle = function()
	if M.options.enabled then
		M.options.enabled = false
		highlights.clear_windows()
		M._cleanup_autocmds()
	else
		M.options.enabled = true
		highlights.setup_highlights(M.options)
		highlights.update_windows(M.options)
		M._setup_autocmds()
	end
end

return M
