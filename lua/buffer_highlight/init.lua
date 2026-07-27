local M = {}

local config = {
	focused_bg = "NONE",
	unfocused_bg = "#1a1a2e",
	interpolation = true,
}

local win_colors = {}
local color_counter = 0

local function hex_to_rgb(hex)
	hex = hex:gsub("#", "")
	return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function rgb_to_hex(r, g, b)
	return string.format("#%02x%02x%02x", r, g, b)
end

local function hsl_to_hex(h, s, l)
	s = s / 100
	l = l / 100
	local c = (1 - math.abs(2 * l - 1)) * s
	local x = c * (1 - math.abs((h / 60) % 2 - 1))
	local m = l - c / 2
	local r, g, b = 0, 0, 0
	if h < 60 then r, g, b = c, x, 0
	elseif h < 120 then r, g, b = x, c, 0
	elseif h < 180 then r, g, b = 0, c, x
	elseif h < 240 then r, g, b = 0, x, c
	elseif h < 300 then r, g, b = x, 0, c
	else r, g, b = c, 0, x
	end
	return rgb_to_hex(
		math.floor((r + m) * 255),
		math.floor((g + m) * 255),
		math.floor((b + m) * 255)
	)
end

local function interpolate_color(color1, color2, t)
	local r1, g1, b1 = hex_to_rgb(color1)
	local r2, g2, b2 = hex_to_rgb(color2)
	local r = math.floor(r1 + (r2 - r1) * t)
	local g = math.floor(g1 + (g2 - g1) * t)
	local b = math.floor(b1 + (b2 - b1) * t)
	return rgb_to_hex(r, g, b)
end

local function get_normal_bg()
	local hl = vim.api.nvim_get_hl(0, { name = "Normal" })
	if hl and hl.bg then
		local bg = hl.bg
		return rgb_to_hex(
			math.floor(bg / 65536) % 256,
			math.floor(bg / 256) % 256,
			bg % 256
		)
	end
	return nil
end

local function generate_distinct_color(index)
	local hues = { 240, 260, 280, 300, 320, 200, 220, 180 }
	local hue = hues[((index - 1) % #hues) + 1]
	local saturation = 60
	local lightness = 20
	return hsl_to_hex(hue, saturation, lightness)
end

local function get_color_for_win(winid)
	if not win_colors[winid] then
		color_counter = color_counter + 1
		win_colors[winid] = generate_distinct_color(color_counter)
	end
	return win_colors[winid]
end

local function apply_highlights()
	local focused_win = vim.api.nvim_get_current_win()

	for _, winid in ipairs(vim.api.nvim_list_wins()) do
		if winid == focused_win then
			if config.focused_bg == "NONE" or config.focused_bg == nil then
				vim.api.nvim_win_set_option(winid, "winhighlight", "")
			else
				vim.api.nvim_win_set_option(
					winid,
					"winhighlight",
					"Normal:BufferHighlightFocused"
				)
			end
		else
			local color = get_color_for_win(winid)
			local hl_name = "BufferHighlightWin" .. winid
			vim.api.nvim_set_hl(0, hl_name, { bg = color })
			vim.api.nvim_win_set_option(winid, "winhighlight", "Normal:" .. hl_name)
		end
	end
end

local function cleanup_closed_wins()
	local current_wins = {}
	for _, winid in ipairs(vim.api.nvim_list_wins()) do
		current_wins[winid] = true
	end
	for winid in pairs(win_colors) do
		if not current_wins[winid] then
			win_colors[winid] = nil
		end
	end
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})

	if config.focused_bg and config.focused_bg ~= "NONE" then
		vim.api.nvim_set_hl(0, "BufferHighlightFocused", { bg = config.focused_bg })
	end

	vim.api.nvim_create_autocmd({ "WinEnter", "WinClosed", "BufEnter" }, {
		callback = function()
			vim.schedule(function()
				cleanup_closed_wins()
				apply_highlights()
			end)
		end,
	})

	apply_highlights()
end

return M
