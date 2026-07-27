local M = {}

M.focused_hl = "BufferHighlightFocused"
M.unfocused_hl = "BufferHighlightUnfocused"
M.distinct_hl_prefix = "BufferHighlightDist"

local function hex_to_rgb(hex)
	hex = hex:gsub("#", "")
	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	return r, g, b
end

local function rgb_to_hex(r, g, b)
	return string.format("#%02x%02x%02x", r, g, b)
end

local function interpolate_rgb(hex1, hex2, t)
	local r1, g1, b1 = hex_to_rgb(hex1)
	local r2, g2, b2 = hex_to_rgb(hex2)
	local r = math.floor(r1 + (r2 - r1) * t + 0.5)
	local g = math.floor(g1 + (g2 - g1) * t + 0.5)
	local b = math.floor(b1 + (b2 - b1) * t + 0.5)
	return rgb_to_hex(r, g, b)
end

local function create_hl_group(name, gui_bg, cterm_bg)
	if not gui_bg then
		return
	end
	vim.api.nvim_set_hl(0, name, {
		bg = gui_bg,
		ctermbg = cterm_bg or "NONE",
	})
end

local function get_tree_distances(tree, focused_win)
	local graph = {}

	local function add_edge(a, b)
		if a ~= b then
			graph[a] = graph[a] or {}
			graph[b] = graph[b] or {}
			graph[a][b] = true
			graph[b][a] = true
		end
	end

	local function process_group(wins)
		for i = 1, #wins do
			for j = i + 1, #wins do
				add_edge(wins[i], wins[j])
			end
		end
	end

	local function traverse(node)
		if node.winid then
			return { node.winid }
		end
		local all_wins = {}
		for _, child in ipairs(node.nodes) do
			local child_wins = traverse(child)
			if child_wins then
				for _, w in ipairs(child_wins) do
					table.insert(all_wins, w)
				end
			end
		end
		if #all_wins > 1 then
			process_group(all_wins)
		end
		return all_wins
	end

	traverse(tree)

	local distances = {}
	distances[focused_win] = 0
	local queue = { focused_win }
	local head = 1

	while head <= #queue do
		local current = queue[head]
		head = head + 1
		for neighbor, _ in pairs(graph[current] or {}) do
			if distances[neighbor] == nil then
				distances[neighbor] = distances[current] + 1
				table.insert(queue, neighbor)
			end
		end
	end

	return distances
end

local function get_distances(focused_win)
	local ok, tree = pcall(vim.api.nvim_tabpage_get_tree, 0)
	if ok and tree then
		return get_tree_distances(tree, focused_win)
	end
	return { [focused_win] = 0 }
end

M.setup_highlights = function(opts)
	create_hl_group(M.focused_hl, opts.focused_bg, opts.focused_ctermbg)
	create_hl_group(M.unfocused_hl, opts.unfocused_bg, opts.unfocused_ctermbg)
end

M.update_windows = function(opts)
	local ok, wins = pcall(vim.api.nvim_tabpage_list_wins, 0)
	if not ok then
		wins = {}
	end
	local focused_win = vim.api.nvim_get_current_win()
	local distances = get_distances(focused_win)

	local max_dist = 0
	for _, dist in pairs(distances) do
		if dist > max_dist then
			max_dist = dist
		end
	end

	local use_interpolation = opts.interpolation ~= false
	and opts.focused_bg ~= nil
	and opts.unfocused_bg ~= nil
	and opts.focused_bg ~= "NONE"
	and opts.unfocused_bg ~= "NONE"

	for _, win in ipairs(wins) do
		local dist = distances[win] or 0
		local hl_name

		if use_interpolation and max_dist > 0 and dist > 0 then
			local t = dist / max_dist
			local bg = interpolate_rgb(opts.focused_bg, opts.unfocused_bg, t)
			hl_name = string.format("%s%d", M.distinct_hl_prefix, dist)
			create_hl_group(hl_name, bg, nil)
		elseif win == focused_win and opts.focused_bg then
			hl_name = M.focused_hl
		elseif opts.unfocused_bg then
			hl_name = M.unfocused_hl
		end

		local wh
		if hl_name then
			wh = "Normal:" .. hl_name
		end

		local ok3 = pcall(vim.api.nvim_win_set_option_value, win, "winhighlight", wh or "")
		if not ok3 then
			pcall(vim.fn.setwinvar, win, "&winhighlight", wh or "")
		end
	end
end

M.clear_windows = function()
	local ok, wins = pcall(vim.api.nvim_tabpage_list_wins, 0)
	if not ok then
		return
	end
	for _, win in ipairs(wins) do
		pcall(vim.fn.setwinvar, win, "&winhighlight", "")
	end
end

return M
