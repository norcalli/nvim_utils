require 'nvim_utils'

local gui00        = "282a36"
local gui01        = "34353e"
local gui02        = "43454f"
local gui03        = "78787e"
local gui04        = "a5a5a9"
local gui05        = "e2e4e5"
local gui06        = "eff0eb"
local gui07        = "f1f1f0"
local gui08        = "ff5c57"
local gui09        = "ff9f43"
local gui0A        = "f3f99d"
local gui0B        = "5af78e"
local gui0C        = "9aedfe"
local gui0D        = "57c7ff"
local gui0E        = "ff6ac1"
local gui0F        = "b2643c"

-- " Terminal color definitions
local cterm00        = "00"
local cterm03        = "08"
local cterm05        = "07"
local cterm07        = "15"
local cterm08        = "01"
local cterm0A        = "03"
local cterm0B        = "02"
local cterm0C        = "06"
local cterm0D        = "04"
local cterm0E        = "05"

local cterm01, cterm02, cterm04, cterm06, cterm09, cterm0F

if use_256_colorspace then
  cterm01 = "18"
  cterm02 = "19"
  cterm04 = "20"
  cterm06 = "21"
  cterm09 = "16"
  cterm0F = "17"
else
  cterm01 = "10"
  cterm02 = "11"
  cterm04 = "12"
  cterm06 = "13"
  cterm09 = "09"
  cterm0F = "14"
end

-- " Neovim terminal colours
if nvim.fn.has("nvim") then
  local terminal_color_0 =  "#282a36"
  local terminal_color_1 =  "#ff5c57"
  local terminal_color_2 =  "#5af78e"
  local terminal_color_3 =  "#f3f99d"
  local terminal_color_4 =  "#57c7ff"
  local terminal_color_5 =  "#ff6ac1"
  local terminal_color_6 =  "#9aedfe"
  local terminal_color_7 =  "#e2e4e5"
  local terminal_color_8 =  "#78787e"
  local terminal_color_9 =  "#ff5c57"
  local terminal_color_10 = "#5af78e"
  local terminal_color_11 = "#f3f99d"
  local terminal_color_12 = "#57c7ff"
  local terminal_color_13 = "#ff6ac1"
  local terminal_color_14 = "#9aedfe"
  local terminal_color_15 = "#f1f1f0"
  local terminal_color_background = terminal_color_0
  local terminal_color_foreground = terminal_color_5
  if nvim.o.background == "light" then
    local terminal_color_background = terminal_color_7
    local terminal_color_foreground = terminal_color_2
	end
elseif nvim.fn.has("terminal") then
	local terminal_ansi_colors = { "#282a36",
		"#ff5c57",
		"#5af78e",
		"#f3f99d",
		"#57c7ff",
		"#ff6ac1",
		"#9aedfe",
		"#e2e4e5",
		"#78787e",
		"#ff5c57",
		"#5af78e",
		"#f3f99d",
		"#57c7ff",
		"#ff6ac1",
		"#9aedfe",
		"#f1f1f0",
	}
end

-- nvim.command "hi clear"
-- nvim.command "syntax reset"

local function highlight(group, guifg, guibg, ctermfg, ctermbg, attr, guisp)
	local parts = {group}
	if guifg then table.insert(parts, "guifg=#"..guifg) end
	if guibg then table.insert(parts, "guibg=#"..guibg) end
	if ctermfg then table.insert(parts, "ctermfg="..ctermfg) end
	if ctermbg then table.insert(parts, "ctermbg="..ctermbg) end
	if attr then
		table.insert(parts, "gui="..attr)
		table.insert(parts, "cterm="..attr)
	end
	if guisp then table.insert(parts, "guisp=#"..guisp) end
	-- nvim_print(parts)
	-- nvim.ex.highlight(parts)
	vim.api.nvim_command('highlight '..table.concat(parts, ' '))
end

-- Vim editor colors
highlight("Normal",        gui05, gui00, cterm05, cterm00, nil, nil)
highlight("Bold",          nil, nil, nil, nil, "bold", nil)
highlight("Debug",         gui08, nil, cterm08, nil, nil, nil)
highlight("Directory",     gui0D, nil, cterm0D, nil, nil, nil)
highlight("Error",         gui00, gui08, cterm00, cterm08, nil, nil)
highlight("ErrorMsg",      gui08, gui00, cterm08, cterm00, nil, nil)
highlight("Exception",     gui08, nil, cterm08, nil, nil, nil)
highlight("FoldColumn",    gui0C, gui01, cterm0C, cterm01, nil, nil)
highlight("Folded",        gui03, gui01, cterm03, cterm01, nil, nil)
highlight("IncSearch",     gui01, gui09, cterm01, cterm09, "none", nil)
highlight("Italic",        nil, nil, nil, nil, "none", nil)
highlight("Macro",         gui08, nil, cterm08, nil, nil, nil)
highlight("MatchParen",    nil, gui03, nil, cterm03,  nil, nil)
highlight("ModeMsg",       gui0B, nil, cterm0B, nil, nil, nil)
highlight("MoreMsg",       gui0B, nil, cterm0B, nil, nil, nil)
highlight("Question",      gui0D, nil, cterm0D, nil, nil, nil)
highlight("Search",        gui01, gui0A, cterm01, cterm0A,  nil, nil)
highlight("Substitute",    gui01, gui0A, cterm01, cterm0A, "none", nil)
highlight("SpecialKey",    gui03, nil, cterm03, nil, nil, nil)
highlight("TooLong",       gui08, nil, cterm08, nil, nil, nil)
highlight("Underlined",    gui08, nil, cterm08, nil, nil, nil)
highlight("Visual",        nil, gui02, nil, cterm02, nil, nil)
highlight("VisualNOS",     gui08, nil, cterm08, nil, nil, nil)
highlight("WarningMsg",    gui08, nil, cterm08, nil, nil, nil)
highlight("WildMenu",      gui08, gui0A, cterm08, nil, nil, nil)
highlight("Title",         gui0D, nil, cterm0D, nil, "none", nil)
highlight("Conceal",       gui0D, gui00, cterm0D, cterm00, nil, nil)
highlight("Cursor",        gui00, gui05, cterm00, cterm05, nil, nil)
highlight("NonText",       gui03, nil, cterm03, nil, nil, nil)
highlight("LineNr",        gui03, gui01, cterm03, cterm01, nil, nil)
highlight("SignColumn",    gui03, gui01, cterm03, cterm01, nil, nil)
highlight("StatusLine",    gui04, gui02, cterm04, cterm02, "none", nil)
highlight("StatusLineNC",  gui03, gui01, cterm03, cterm01, "none", nil)
highlight("VertSplit",     gui02, gui02, cterm02, cterm02, "none", nil)
highlight("ColorColumn",   nil, gui01, nil, cterm01, "none", nil)
highlight("CursorColumn",  nil, gui01, nil, cterm01, "none", nil)
highlight("CursorLine",    nil, gui01, nil, cterm01, "none", nil)
highlight("CursorLineNr",  gui04, gui01, cterm04, cterm01, nil, nil)
highlight("QuickFixLine",  nil, gui01, nil, cterm01, "none", nil)
highlight("PMenu",         gui05, gui01, cterm05, cterm01, "none", nil)
highlight("PMenuSel",      gui01, gui05, cterm01, cterm05, nil, nil)
highlight("TabLine",       gui03, gui01, cterm03, cterm01, "none", nil)
highlight("TabLineFill",   gui03, gui01, cterm03, cterm01, "none", nil)
highlight("TabLineSel",    gui0B, gui01, cterm0B, cterm01, "none", nil)

-- Standard syntax highlighting
highlight("Boolean",      gui09, nil, cterm09, nil, nil, nil)
highlight("Character",    gui08, nil, cterm08, nil, nil, nil)
highlight("Comment",      gui03, nil, cterm03, nil, nil, nil)
highlight("Conditional",  gui0E, nil, cterm0E, nil, nil, nil)
highlight("Constant",     gui09, nil, cterm09, nil, nil, nil)
highlight("Define",       gui0E, nil, cterm0E, nil, "none", nil)
highlight("Delimiter",    gui0F, nil, cterm0F, nil, nil, nil)
highlight("Float",        gui09, nil, cterm09, nil, nil, nil)
highlight("Function",     gui0D, nil, cterm0D, nil, nil, nil)
highlight("Identifier",   gui08, nil, cterm08, nil, "none", nil)
highlight("Include",      gui0D, nil, cterm0D, nil, nil, nil)
highlight("Keyword",      gui0E, nil, cterm0E, nil, nil, nil)
highlight("Label",        gui0A, nil, cterm0A, nil, nil, nil)
highlight("Number",       gui09, nil, cterm09, nil, nil, nil)
highlight("Operator",     gui05, nil, cterm05, nil, "none", nil)
highlight("PreProc",      gui0A, nil, cterm0A, nil, nil, nil)
highlight("Repeat",       gui0A, nil, cterm0A, nil, nil, nil)
highlight("Special",      gui0C, nil, cterm0C, nil, nil, nil)
highlight("SpecialChar",  gui0F, nil, cterm0F, nil, nil, nil)
highlight("Statement",    gui08, nil, cterm08, nil, nil, nil)
highlight("StorageClass", gui0A, nil, cterm0A, nil, nil, nil)
highlight("String",       gui0B, nil, cterm0B, nil, nil, nil)
highlight("Structure",    gui0E, nil, cterm0E, nil, nil, nil)
highlight("Tag",          gui0A, nil, cterm0A, nil, nil, nil)
highlight("Todo",         gui0A, gui01, cterm0A, cterm01, nil, nil)
highlight("Type",         gui0A, nil, cterm0A, nil, "none", nil)
highlight("Typedef",      gui0A, nil, cterm0A, nil, nil, nil)

-- nvim.command 'syntax on'

