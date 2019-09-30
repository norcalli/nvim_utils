require 'nvim_utils'
-- require 'base16-snazzy'
local todo_mappings = require 'todo'

function text_object_replace(is_visual_mode)
  local register = nvim.v.register
	local function replace()
		return nvim.fn.getreg(register, 1, 1)
	end
  if is_visual_mode then
    local visual_mode = nvim_visual_mode()
    nvim_buf_transform_region_lines(nil, '<', '>', visual_mode, replace)
  else
		-- It's unfortunate that lines must be fetched here considering it's not used,
		-- but for a "char" visual mode, it's required regardless. For lines, it wouldn't be,
		-- but that optimization is not made yet.
		-- TODO investigate if nvim_text_operator_transform_selection can be optimized
    nvim_text_operator_transform_selection(replace)
  end
end

local function duplicate(lines, mode)
  if mode == VISUAL_MODE.line then
    return vim.tbl_flatten {lines, lines}
  elseif mode == VISUAL_MODE.char then
    if #lines == 0 then
      return lines
    end
    if #lines == 1 then
      return {lines[1]..lines[1]}
    end
    local first_line = table.remove(lines, 1)
    local last_line = table.remove(lines)
    return vim.tbl_flatten {first_line, lines, last_line..first_line, lines, last_line}
  end
end

function text_object_duplicate(is_visual_mode)
  if is_visual_mode then
    local visual_mode = nvim_visual_mode()
    nvim_buf_transform_region_lines(nil, '<', '>', visual_mode, duplicate)
  else
    nvim_text_operator_transform_selection(duplicate)
  end
end

function text_object_comment_and_duplicate(is_visual_mode)
  local visual_mode = VISUAL_MODE.line
  local commentstring = nvim.bo.commentstring
  local function comment_dupe(lines)
    local commented = {}
    for _, line in ipairs(lines) do
      table.insert(commented, commentstring:format(line))
    end
    return vim.tbl_flatten { lines, commented }
  end
  if is_visual_mode then
    nvim_buf_transform_region_lines(nil, '<', '>', visual_mode, comment_dupe)
  else
    nvim_text_operator_transform_selection(comment_dupe, visual_mode)
  end
end

local function text_object_define(mapping, function_name)
  local options = { silent = true, noremap = true }
  nvim.set_keymap('n', mapping, ("<Cmd>lua %s(%s)<CR>"):format(function_name, false), options)
  nvim.set_keymap('x', mapping, (":lua %s(%s)<CR>"):format(function_name, true), options)
  -- TODO figure out why <Cmd> mappings for this seem to not be working.
  -- nvim.set_keymap('x', mapping, ("<Cmd>lua %s(%s)<CR>"):format(function_name, true), options)
  -- nvim.ex.nnoremap {"<silent>", mapping, (":lua %s(%s)<CR>"):format(function_name, false)}
  -- nvim.ex.xnoremap {"<silent>", mapping, (":lua %s(%s)<CR>"):format(function_name, true)}
end

text_object_define(" xr", "text_object_replace")
text_object_define(" xd", "text_object_duplicate")
text_object_define(" xy", "text_object_comment_and_duplicate")
text_object_define("gy", "text_object_comment_and_duplicate")

-- local default_options = { silent = true; unique = true; }
local default_options = { silent = true; }

local text_object_mappings = {
	-- ["n xd"]  = { [[<Cmd>lua text_object_duplicate(false)<CR>]],             noremap = true; };
	-- ["n xr"]  = { [[<Cmd>lua text_object_replace(false)<CR>]],               noremap = true; };
	-- ["n xy"]  = { [[<Cmd>lua text_object_comment_and_duplicate(false)<CR>]], noremap = true; };
	-- ["x xd"]  = { [[:lua text_object_duplicate(true)<CR>]],                  noremap = true; };
	-- ["x xr"]  = { [[:lua text_object_replace(true)<CR>]],                    noremap = true; };
	-- ["x xy"]  = { [[:lua text_object_comment_and_duplicate(true)<CR>]],      noremap = true; };
	["n xdd"] = { [[ xd_]],                  };
	["n xrr"] = { [[ xr_]],                  };
	["n xyy"] = { [[ xyl]],                  };
	["oil"]   = { [[<Cmd>normal! $v^<CR>]],  noremap = true; };
	["xil"]   = { [[<Cmd>normal! $v^<CR>]],  noremap = true; };
	["oal"]   = { [[<Cmd>normal! V<CR>]],    noremap = true; };
	["xal"]   = { [[<Cmd>normal! V<CR>]],    noremap = true; };
	["oae"]   = { [[<Cmd>normal! ggVG<CR>]], noremap = true; };
	["xae"]   = { [[<Cmd>normal! ggVG<CR>]], noremap = true; };
	["o\\"]   = { [[$]], noremap = true; };
	["x\\"]   = { [[$]], noremap = true; };
}

local function map_cmd(...)
	return { ("<Cmd>%s<CR>"):format(table.concat(vim.tbl_flatten {...}, " ")), noremap = true; }
end

local function map_set(...)
	return { ("<Cmd>silent set %s<CR>"):format(table.concat(vim.tbl_flatten {...}, " ")), noremap = true; }
end

local function toggle_settings(...)
	local parts = {}
	for _, setting in ipairs(vim.tbl_flatten{...}) do
		table.insert(parts, ("%s! %s?"):format(setting, setting))
	end
	return parts
end

local function map_toggle_settings(...)
	local parts = {}
	for _, setting in ipairs(vim.tbl_flatten{...}) do
		table.insert(parts, ("%s! %s?"):format(setting, setting))
	end
	return map_set(parts)
end

-- The mapping helps a lot with deduplicating, but you could still bypass it with key combos
-- which are valid both in lowercase and uppercase like <CR> and <cr>
local other_mappings = {
	-- Highlight current cword
	["n[,"]  = { function()
		-- \C forces matching exact case
		-- \M forces nomagic interpretation
		-- \< and \> denote whole word match
		nvim.fn.setreg("/", ([[\C\M\<%s\>]]):format(nvim.fn.expand("<cword>")), "c")
		nvim.o.hlsearch = true
	end };
	-- Highlight current selection
	["x[,"]  = { function()
		local selection = table.concat(nvim_buf_get_region_lines(0, '<', '>', VISUAL_MODE.char), '\n')
		nvim.fn.setreg("/", ([[\C\M%s]]):format(selection), "c")
		nvim.o.hlsearch = true
	end };
	["n\\ "] = { function()
		nvim.put({" "}, "c", false, false)
		-- local pos = vim.api.nvim_win_get_cursor(0)
		-- nvim_buf_transform_region_lines(nil, pos, pos, VISUAL_MODE.char, function(lines) return {" "..lines[1]} end)
	end };
	["n\\<CR>"] = { function()
		-- nvim.put({""}, "c", false, false)
		local pos = vim.api.nvim_win_get_cursor(0)
		nvim_buf_transform_region_lines(nil, pos, pos, VISUAL_MODE.char, function(lines)
			return {"", lines[1]}
		end)
		-- TODO to indent or not indent? That is the question
		-- nvim.ex.normal_("=j")
	end };
	["n jj"] = { "\\<CR>" };
	["i<c-e>"] = { function()
		local pos = nvim.win_get_cursor(0)
		local line = nvim.buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
		nvim.win_set_cursor(0, {pos[1], #line})
	end };
	["i<c-a>"] = { function()
		local pos = nvim.win_get_cursor(0)
		local line = nvim.buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
		local _, start = line:find("^%s+")
		nvim.win_set_cursor(0, {pos[1], start})
	end };
	["i<c-t>"] = { function()
		local pos = nvim.win_get_cursor(0)
		nvim_buf_transform_region_lines(0, pos, pos, VISUAL_MODE.line, function(lines)
			return {lines[1]:sub(1, pos[2])}
		end)
	end };
	-- This should work, but <Cmd> mappings seem to have difficulty with this for some reason.
	-- ["v>"] = { function()
	-- 	nvim_buf_transform_region_lines(0, '<', '>', 'line', function(lines)
	-- 		local prefix
	-- 		if not nvim.bo.expandtab then
	-- 			prefix = "\t"
	-- 		else
	-- 			prefix = string.rep(" ", nvim.fn.shiftwidth())
	-- 		end
	-- 		for i, line in ipairs(lines) do
	-- 			lines[i] = prefix..line
	-- 		end
	-- 		return lines
	-- 	end)
	-- end };
	-- I like neosnippet expansion on <c-k> therefore remap <c-j> to <c-k>
	["i<c-j>"] = { "<c-k>",                             noremap = true; };
	["i<c-k>"] = { "<Plug>(neosnippet_expand_or_jump)", noremap = false; };
	["s<c-k>"] = { "<Plug>(neosnippet_expand_or_jump)", noremap = false; };
	["x<c-k>"] = { "<Plug>(neosnippet_expand_target)",  noremap = false; };

	-- Indent shit
	["x>"]     = { "<Cmd>normal! >gv<CR>",              noremap = true; };
	["x<"]     = { "<Cmd>normal! <gv<CR>",              noremap = true; };

	-- Misc bindings
	["nQ"]     = { "<Cmd>bd<CR>",                       noremap = true; };
	-- This goes back a space, I wonder if there's a programmatic way to exit insert mode
	["i<c-c>"] = { "<esc>",                             noremap = true; };
	-- Pop into editing a command quickly
	["n :"]    = { ":<c-f>cc",                          noremap = true; };

	-- Diff bindings
	["n do"]   = { "<Cmd>diffoff!<CR>",                 noremap = true; };
	["n dt"]   = { "<Cmd>diffthis<CR>",                 noremap = true; };
	["n du"]   = { "<Cmd>diffupdate<CR>",               noremap = true; };
	["n dg"]   = { "<Cmd>diffget<CR>",                  noremap = true; };
	["n dp"]   = { "<Cmd>diffput<CR>",                  noremap = true; };
	["x dp"]   = { "<Cmd>diffput<CR>",                  noremap = true; };

	-- TODO insert these into mappings only if the appropriate plugins exist.
	-- git/vim-fugitive aliases/mappings
	["n gS"]   = { [[<Cmd>FZFGFiles?<CR>]],             noremap = true; };
	["n gT"]   = { [[<Cmd>FZFBCommits<CR>]],            noremap = true; };
	["n gb"]   = { [[<Cmd>Gblame<CR>]],                 noremap = true; };
	["n gc"]   = { [[<Cmd>Gcommit<CR>]],                noremap = true; };
	["n gd"]   = { [[<Cmd>Gdiff<CR>]],                  noremap = true; };
	["n ge"]   = { [[<Cmd>Gedit<CR>]],                  noremap = true; };
	["n gl"]   = { [[<Cmd>Gpull<CR>]],                  noremap = true; };
	["n gp"]   = { [[<Cmd>Gpush<CR>]],                  noremap = true; };
	["n gq"]   = { [[<Cmd>Gcommit -m "%"<CR>]],         noremap = true; };
	["n gr"]   = { [[<Cmd>Gread<CR>]],                  noremap = true; };
	["n gs"]   = { [[<Cmd>Gstatus<CR>]],                noremap = true; };
	["n gt"]   = { [[<Cmd>0Glog<CR>]],                  noremap = true; };
	["n gw"]   = { [[<Cmd>Gwrite<CR>]],                 noremap = true; };
	["x gt"]   = { [[:Glog<CR>]],                       noremap = true; };

	["n ldo"]   = { [[<Cmd>LinediffReset<CR>]],         noremap = true; };
	["n ldt"]   = { [[<Cmd>Linediff<CR>]],              noremap = true; };
	["x ldo"]   = { [[<Cmd>LinediffReset<CR>]],         noremap = true; };
	["x ldt"]   = { [[<Cmd>Linediff<CR>]],              noremap = true; };

	["n sw"]   = map_toggle_settings("wrap");
	["n sn"]   = map_toggle_settings("number", "relativenumber");
	["n sb"]   = map_toggle_settings("scb");
	["n sp"]   = map_toggle_settings("paste");
	["n sh"]   = map_toggle_settings("list");
	["n sc"]   = map_toggle_settings("hlsearch");
	["n sP"]   = map_cmd("silent setlocal", toggle_settings("spell"));

	-- Open terminal at $PWD
	["n at"]  = { function()
		-- TODO use terminal api directly?
		nvim.ex.edit("term://$SHELL")
		nvim.ex.startinsert()
	end };
	-- Open terminal at current buffer's directory
	["n aT"]  = { function()
		nvim.ex.edit(("term://%s//$SHELL"):format(nvim.fn.expand("%:h")))
		nvim.ex.startinsert()
	end };
	["n ae"] = { "<Cmd>Explore<CR>", noremap = true };

	-- Insert blank lines after the current line.
	["n] "]    = { function()
		local repetition = nvim.v.count1
		local pos = nvim.win_get_cursor(0)
		nvim_buf_transform_region_lines(0, pos, pos, VISUAL_MODE.line, function(lines)
			for _ = 1, repetition do
				table.insert(lines, '')
			end
			return lines
		end)
	end };
	-- Insert blank lines before the current line.
	["n[ "]    = { function()
		local repetition = nvim.v.count1
		local pos = nvim.win_get_cursor(0)
		nvim_buf_transform_region_lines(0, pos, pos, VISUAL_MODE.line, function(lines)
			local result = {}
			for _ = 1, repetition do
				table.insert(result, '')
			end
			return vim.tbl_flatten {result, lines}
		end)
		nvim.win_set_cursor(0, {pos[1]+repetition, pos[2]})
	end };

	-- Transpose line downwards
	["n]p"]    = { function()
		nvim.put(nvim.fn.getreg(nvim.v.register, 1, true), "l", true, false)
	end };
	["n[p"]    = { function()
		nvim.put(nvim.fn.getreg(nvim.v.register, 1, true), "l", false, false)
	end };
	-- Transpose line downwards
	["n]e"]    = { function()
		local repetition = nvim.v.count1
		local pos = nvim.win_get_cursor(0)
		nvim_buf_transform_region_lines(0, pos, pos[1] + repetition, VISUAL_MODE.line, function(lines)
			table.insert(lines, table.remove(lines, 1))
			return lines
		end)
		-- TODO Follow the line or not?
		nvim.win_set_cursor(0, {pos[1] + repetition, pos[2]})
	end };
	-- Transpose line upwards
	["n[e"]    = { function()
		local repetition = nvim.v.count1
		local pos = nvim.win_get_cursor(0)
		nvim_buf_transform_region_lines(0, pos[1] - repetition, pos, VISUAL_MODE.line, function(lines)
			table.insert(lines, 1, table.remove(lines))
			return lines
		end)
		nvim.win_set_cursor(0, {pos[1] - repetition, pos[2]})
	end };

	["nZZ"] = { function()
		if #nvim.list_bufs() > 1 then
			if not nvim.bo.modifiable then
				nvim.command("bd")
			else
				nvim.command("w | bd")
			end
		else
			nvim.command("xit")
		end
		-- if #vim.api.nvim_list_bufs() > 1 then
		-- 	if not vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), "modifiable") then
		-- 		vim.api.nvim_command("bd")
		-- 	else
		-- 		vim.api.nvim_command("w | bd")
		-- 	end
		-- else
		-- 	vim.api.nvim_command("xit")
		-- end
	end };

	["n<A-/>"] = { [[gcl]] };
	["x<A-/>"] = { [[<Cmd>normal gcl<CR>]], noremap = true; };

	["n<A-;>"]  = map_cmd("silent bprev");
	["n<A-\">"] = map_cmd("silent bnext");
	["n<A-'>"]  = map_cmd("silent bnext");

	["i<A-;>"]  = map_cmd("silent bprev");
	["i<A-\">"] = map_cmd("silent bnext");
	["i<A-'>"]  = map_cmd("silent bnext");

	-- TODO replicate BD in lua, which is to delete the current buffer without
	-- closing the window.
	["n<A-c>"]   = map_cmd("silent BD");
	["n<A-S-c>"] = map_cmd("silent BD!");
	["i<A-c>"]   = map_cmd("silent BD");
	["i<A-S-c>"] = map_cmd("silent BD!");

	-- TODO redo in lua
	["n<A-S-n>"] = { [[<c-w>n:set buftype=nofile<CR>]], noremap = true; };

	-- TODO for some reason this doesn't work like I expect.
	-- ["c<C-x>h"]     = { [[expand("%:h")."/"]], nowait = true; noremap = true; expr = true; };
	-- ["c<C-x>p"]     = { [[expand("%:p")]],     nowait = true; noremap = true; expr = true; };
	-- ["c<C-x>t"]     = { [[expand("%:t")]],     nowait = true; noremap = true; expr = true; };
	-- ["c<C-x><c-x>"] = { [[expand("%")]],       nowait = true; noremap = true; expr = true; };

	--	["i<c-c>"] = { "<esc>l", noremap = true; };
	-- TODO Try to do it programmatically
	-- ["i<c-c>"] = { function()
	-- 	local pos = nvim.win_get_cursor(0)
	-- 	nvim.feedkeys("<ESC>", 'n', false)
	-- 	-- nvim.ex.stopinsert()
	-- 	nvim.win_set_cursor(0, pos)
	-- end };

	["nY"] = { [["+y]], noremap = true; };
	["xY"] = { [["+y]], noremap = true; };

	-- replace 'f' with 1-char Sneak
	["n<A-f>"] = { [[<Plug>Sneak_f]] };
	["o<A-f>"] = { [[<Plug>Sneak_f]] };
	["x<A-f>"] = { [[<Plug>Sneak_f]] };
	["n<A-F>"] = { [[<Plug>Sneak_F]] };
	["o<A-F>"] = { [[<Plug>Sneak_F]] };
	["x<A-F>"] = { [[<Plug>Sneak_F]] };

	-- replace 't' with 1-char Sneak
	["n<A-t>"] = { [[<Plug>Sneak_t]] };
	["o<A-t>"] = { [[<Plug>Sneak_t]] };
	["x<A-t>"] = { [[<Plug>Sneak_t]] };
	["n<A-T>"] = { [[<Plug>Sneak_T]] };
	["o<A-T>"] = { [[<Plug>Sneak_T]] };
	["x<A-T>"] = { [[<Plug>Sneak_T]] };

	["ngx"] = map_cmd [[call jobstart(["ldo", expand("<cfile>")])]];
	-- I wish I could use <Cmd> for this.
	["xgx"] = { [[:lua spawn("ldo", { args = { nvim_selection() } })<CR>]], noremap = true; };
}

local motion_mappings = {
	["n<A-j>"] = { [[<c-w>j]], noremap = true; };
	["n<A-k>"] = { [[<c-w>k]], noremap = true; };
	["n<A-h>"] = { [[<c-w>h]], noremap = true; };
	["n<A-l>"] = { [[<c-w>l]], noremap = true; };
	["n<A-s>"] = { [[<c-w>s]], noremap = true; };
	["n<A-v>"] = { [[<c-w>v]], noremap = true; };
	["n<A-o>"] = { [[<c-w>o]], noremap = true; };

	["n<A-0>"] = { [[<c-w>=]], noremap = true; };
	["n<A-=>"] = { [[<c-w>+]], noremap = true; };
	["n<A-->"] = { [[<c-w>-]], noremap = true; };
	["n<A-<>"] = { [[<c-w><]], noremap = true; };
	["n<A->>"] = { [[<c-w>>]], noremap = true; };
	["n<A-q>"] = { [[<c-w>q]], noremap = true; };
	["n<A-n>"] = { [[<c-w>n]], noremap = true; };

	["n<A-z>"] = { [[<c-w>z]], noremap = true; };

	["n<A-H>"] = { [[<c-w>H]], noremap = true; };
	["n<A-J>"] = { [[<c-w>J]], noremap = true; };
	["n<A-K>"] = { [[<c-w>K]], noremap = true; };
	["n<A-L>"] = { [[<c-w>L]], noremap = true; };

	["n<A-u>"] = { [[<c-u>]], noremap = true; };
	["n<A-d>"] = { [[<c-d>]], noremap = true; };

	-- -- TODO autocreate these from the existing n<A-*>
	-- ["i<A-z>"] = { [[<c-o><c-w>z]], noremap = true; };
	-- ["i<A-H>"] = { [[<c-o><c-w>H]], noremap = true; };
	-- ["i<A-J>"] = { [[<c-o><c-w>J]], noremap = true; };
	-- ["i<A-K>"] = { [[<c-o><c-w>K]], noremap = true; };
	-- ["i<A-L>"] = { [[<c-o><c-w>L]], noremap = true; };
}

local insert_motion_mappings = {}
for k, v in pairs(motion_mappings) do
	insert_motion_mappings["i"..k:sub(2)] = map_cmd("normal! "..v[1])
end

local terminal_motion_mappings = {}
for k, v in pairs(motion_mappings) do
	terminal_motion_mappings["t"..k:sub(2)] = { [[<C-\><C-n>]]..v[1], noremap = true; }
--	terminal_motion_mappings["t"..k:sub(2)] = map_cmd("stopinsert | normal! "..v[1])
end

local mappings = {
	text_object_mappings,
	other_mappings,
	motion_mappings,
	insert_motion_mappings,
	terminal_motion_mappings,
}

nvim_apply_mappings(vim.tbl_extend("error", unpack(mappings)), default_options)

FILETYPE_HOOKS = {
	todo = function()
		todo_mappings["n AZ"] = { function()
			nvim_print("hi")
		end }
		nvim.command('setl foldlevel=2')
		-- TODO why doesn't this work?
		-- nvim.bo.foldlevel = 2
		nvim_apply_mappings(todo_mappings, { buffer = true })
	end;
	sql = function()
		nvim.bo.commentstring = "-- %s"
		nvim.bo.formatprg = "pg_format -"
	end;
	rust = function()
		local mappings = {
			["n af"] = { "<Cmd>RustFmt<CR>", noremap = true; };
			["x af"] = { ":RustFmtRange<CR>", noremap = true; };
		}
		nvim_apply_mappings(mappings, { buffer = true; silent = true; })
	end;
	i3config = function()
		local mappings = {
			["n ab"] = { "<Cmd>.w !xargs swaymsg --<CR>", noremap = true; };
			["x ab"] = { ":w !xargs swaymsg --<CR>", noremap = true; };
		}
		nvim_apply_mappings(mappings, { buffer = true; silent = true; })
	end;
	jq = function()
		nvim.bo.commentstring = "# %s"
	end;
	terraform = function()
		nvim.bo.commentstring = "# %s"
	end;
	["play2-conf"] = function()
		nvim.bo.commentstring = "# %s"
	end;
	lua = function()
		local mappings = {
			-- ["n all"] = { [[<Cmd>.!lualambda<CR>]], noremap = true; };
			-- ["x all"] = { [[:!lualambda<CR>]], noremap = true; };
			["n aL"]  = { [[<Cmd>.!lualambda<CR>]], noremap = true; };
			["x aL"]  = { [[:!lualambda<CR>]], noremap = true; };
			["n ab"]  = { [[<Cmd>.luado loadstring(line)()<CR>]], noremap = true; };
			["x ab"]  = { [[<Cmd>lua loadstring(nvim_selection())()<CR>]], noremap = true; };
		}
		nvim_apply_mappings(mappings, { buffer = true; silent = true; })
	end;
	json = function()
		-- setl formatprg=json_reformat shiftwidth=4 tabstop=4
		nvim.bo.formatprg = "json-reformat"
		nvim.bo.shiftwidth = 4
		nvim.bo.tabstop = 4
	end;
	crontab = function()
		nvim.bo.backup = false
		nvim.bo.writebackup = false
	end;
	matlab = function()
		nvim.bo.commentstring = "% %s"
		nvim.command [[command! -buffer Start term /Applications/MATLAB_R2015b.app/bin/matlab -nodesktop]]
		nvim.command [[command! -buffer Run let @"=expand("%:r.h")."\n\n" | b matlab | norm pa]]
		local mappings = {
			["n<leader>m"] = map_cmd("Run");
		}
		nvim_apply_mappings(mappings, { buffer = true; silent = true; })
	end;
	go = function()
		local mappings = {
			["n<leader>i"] = { "<Plug>(go-info)" };
		}
		nvim_apply_mappings(mappings, { buffer = true; silent = true; })
	end;
	python = function()
		nvim.bo.makeprg = "python3 -mdoctest %"
	end;
	scala = function()
		local mappings = {
			["n af"] = map_cmd [[!scalafmt %]];
		}
		nvim_apply_mappings(mappings, { buffer = true; silent = true; })

		nvim.bo.errorformat = table.concat({
			[[%E %#[error] %f:%l: %m]],
			[[%C %#[error] %p^]],
			[[%C %#[error] %m]],
			[[%-C%.%#]],
			[[%Z]],
			[[%W %#[warn] %f:%l: %m]],
			[[%C %#[warn] %p^]],
			[[%C %#[warn] %m]],
			[[%-C%.%#]],
			[[%Z]],
			[[%-G%.%#]],
		}, ',')
	end;
}

local global_settings = {
	autoread       = true;
	background     = "dark";
	cmdheight      = 3;
	colorcolumn    = "120";
	diffopt        = "internal,filler,vertical,iwhite",
	hidden         = true;
	ignorecase     = true;
	inccommand     = "nosplit";
	incsearch      = true;
	laststatus     = 2;
	listchars      = [[eol:$,tab:>-,trail:~,extends:>,precedes:<]];
	modeline       = true;
	-- TODO why did I add this in the first place?
	path           = nvim.o.path..","..nvim.env.PWD,
	printoptions   = "bottom:1in";
	shada          = [[!,'500,<50,s10,h]];
	showcmd        = true;
	showmode       = false;
	smartcase      = true;
	splitbelow     = true;
	-- Don't change the position to the start of the line on bnext or whatnot
	startofline    = false;
	swapfile       = false;
	termguicolors  = true;
	title          = true;
	titlestring    = "%{join(split(getcwd(), '/')[-2:], '/')}";
	viminfo        = [[!,'300,<50,s10,h]];
	wildignorecase = true;
	wildmenu       = true;
	-- " set wildmode=list:longest,full
	wildmode       = "longest:full,full";

	-- Former settings
	-- set expandtab shiftwidth=2 softtabstop=2 tabstop=2
	-- relativenumber = true;
	-- number = true;
}

for name, value in pairs(global_settings) do
	nvim.o[name] = value
end

local autocmds = {
	todo = {
		{"BufEnter",     "*.todo",              "setl ft=todo"};
		{"BufEnter",     "*meus/todo/todo.txt", "setl ft=todo"};
		{"BufReadCmd",   "*meus/todo/todo.txt", [[silent call rclone#load("db:todo/todo.txt")]]};
		{"BufWriteCmd",  "*meus/todo/todo.txt", [[silent call rclone#save("db:todo/todo.txt")]]};
		{"FileReadCmd",  "*meus/todo/todo.txt", [[silent call rclone#load("db:todo/todo.txt")]]};
		{"FileWriteCmd", "*meus/todo/todo.txt", [[silent call rclone#save("db:todo/todo.txt")]]};
	};
	vimrc = {
		{"BufWritePost init.vim nested source $MYVIMRC"};
		{"FileType man setlocal nonumber norelativenumber"};
		{"BufEnter term://* setlocal nonumber norelativenumber"};
	};
}

local function escape_keymap(key)
	-- Prepend with a letter so it can be used as a dictionary key
	return 'k'..key:gsub('.', string.byte)
end

for filetype, _ in pairs(FILETYPE_HOOKS) do
	-- Escape the name to be compliant with augroup names.
	autocmds["LuaFileTypeHook_"..escape_keymap(filetype)] = {
		{"FileType", filetype, ("lua FILETYPE_HOOKS[%q]()"):format(filetype)};
	};
end

nvim_create_augroups(autocmds)

--[[
Use this line to automatically convert `<Cmd>..<CR>` mappings to `map_cmd ...`
I'm not sure which version I like better.

'<,'>s/{.*<cmd>\(.*\)<cr>.*/map_cmd [[\1]];
--]]
