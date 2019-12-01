--- NVIM SPECIFIC SHORTCUTS
local vim = vim
local api = vim.api

VISUAL_MODE = {
	line = "line"; -- linewise
	block = "block"; -- characterwise
	char = "char"; -- blockwise-visual
}

-- TODO I didn't know that api.nvim_buf_* methods could take 0 to signify the
-- current buffer, so refactor potentially everything to avoid the call to
-- api.nvim_get_current_buf

-- An enhanced version of nvim_buf_get_mark which also accepts:
-- - A number as input: which is taken as a line number.
-- - A pair, which is validated and passed through otherwise.
function nvim_mark_or_index(buf, input)
	if type(input) == 'number' then
		-- TODO how to handle column? It would really depend on whether this was the opening mark or ending mark
		-- It also doesn't matter as long as the functions are respecting the mode for transformations
		assert(input ~= 0, "Line number must be >= 1 or <= -1 for last line(s)")
		return {input, 0}
	elseif type(input) == 'table' then
		-- TODO Further validation?
		assert(#input == 2)
		assert(input[1] >= 1)
		return input
	elseif type(input) == 'string' then
		return api.nvim_buf_get_mark(buf, input)
		-- local result = api.nvim_buf_get_mark(buf, input)
		-- if result[2] == 2147483647 then
		-- 	result[2] = -1
		-- end
		-- return result
	end
	error(("nvim_mark_or_index: Invalid input buf=%q, input=%q"):format(buf, input))
end

-- TODO should I be wary of `&selection` in the nvim_buf_get functions?
--[[
" https://stackoverflow.com/questions/1533565/how-to-get-visually-selected-text-in-vimscript
function! s:get_visual_selection()
		" Why is this not a built-in Vim script function?!
		let [line_start, column_start] = getpos("'<")[1:2]
		let [line_end, column_end] = getpos("'>")[1:2]
		let lines = getline(line_start, line_end)
		if len(lines) == 0
				return ''
		endif
		let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
		let lines[0] = lines[0][column_start - 1:]
		return join(lines, "\n")
endfunction
--]]

--- Return the lines of the selection, respecting selection modes.
-- RETURNS: table
function nvim_buf_get_region_lines(buf, mark_a, mark_b, mode)
	mode = mode or VISUAL_MODE.char
	buf = buf or api.nvim_get_current_buf()
	-- TODO keep these? @refactor
	mark_a = mark_a or '<'
	mark_b = mark_b or '>'

	local start = nvim_mark_or_index(buf, mark_a)
  local finish = nvim_mark_or_index(buf, mark_b)
  local lines = api.nvim_buf_get_lines(buf, start[1] - 1, finish[1], false)

	if mode == VISUAL_MODE.line then
		return lines
	end

	if mode == VISUAL_MODE.char then
		-- Order is important. Truncate the end first, because these are not commutative
		if finish[2] ~= 2147483647 then
			lines[#lines] = lines[#lines]:sub(1, finish[2] + 1)
		end
		if start[2] ~= 0 then
			lines[1] = lines[1]:sub(start[2] + 1)
		end
		return lines
	end

	local firstcol = start[2] + 1
	local lastcol = finish[2]
	if lastcol == 2147483647 then
		lastcol = -1
	else
		lastcol = lastcol + 1
	end
	for i, line in ipairs(lines) do
		lines[i] = line:sub(firstcol, lastcol)
	end
	return lines
end

function nvim_buf_set_region_lines(buf, mark_a, mark_b, mode, lines)
	buf = buf or api.nvim_get_current_buf()
	-- TODO keep these? @refactor
	mark_a = mark_a or '<'
	mark_b = mark_b or '>'

	assert(mode == VISUAL_MODE.line, "Other modes aren't supported yet")

	local start = nvim_mark_or_index(buf, mark_a)
	local finish = nvim_mark_or_index(buf, mark_b)

  return api.nvim_buf_set_lines(buf, start[1] - 1, finish[1], false, lines)
end

-- This is actually more efficient if what you're doing is modifying a region
-- because it can save api calls.
-- It's also the only way to do transformations that are correct with `char` mode
-- since it has to have access to the initial values of the region lines.
function nvim_buf_transform_region_lines(buf, mark_a, mark_b, mode, fn)
	buf = buf or api.nvim_get_current_buf()
	-- TODO keep these? @refactor
	mark_a = mark_a or '<'
	mark_b = mark_b or '>'

	local start = nvim_mark_or_index(buf, mark_a)
	local finish = nvim_mark_or_index(buf, mark_b)

	assert(start and finish)

	-- TODO contemplate passing in a function instead of lines as is.
	-- local lines
	-- local function lazy_lines()
	-- 	if not lines then
	-- 		lines = api.nvim_buf_get_lines(buf, start[1] - 1, finish[1], false)
	-- 	end
	-- 	return lines
	-- end

	local lines = api.nvim_buf_get_lines(buf, start[1] - 1, finish[1], false)

	local result
	if mode == VISUAL_MODE.char then
		local prefix = ""
		local suffix = ""
		-- Order is important. Truncate the end first, because these are not commutative
		-- TODO file a bug report about this, it's probably supposed to be -1
		if finish[2] ~= 2147483647 then
			suffix = lines[#lines]:sub(finish[2]+2)
			lines[#lines] = lines[#lines]:sub(1, finish[2] + 1)
		end
		if start[2] ~= 0 then
			prefix = lines[1]:sub(1, start[2])
			lines[1] = lines[1]:sub(start[2] + 1)
		end
		result = fn(lines, mode)

		-- If I take the result being nil as leaving it unmodified, then I can use it
		-- to skip the set part and reuse this just to get fed the input.
		if result == nil then
			return
		end

		-- Sane defaults, assume that they want to erase things if it is empty
		if #result == 0 then
			result = {""}
		end

		-- Order is important. Truncate the end first, because these are not commutative
		-- TODO file a bug report about this, it's probably supposed to be -1
		if finish[2] ~= 2147483647 then
			result[#result] = result[#result]..suffix
		end
		if start[2] ~= 0 then
			result[1] = prefix..result[1]
		end
	elseif mode == VISUAL_MODE.line then
		result = fn(lines, mode)
		-- If I take the result being nil as leaving it unmodified, then I can use it
		-- to skip the set part and reuse this just to get fed the input.
		if result == nil then
			return
		end
	elseif mode == VISUAL_MODE.block then
		local firstcol = start[2] + 1
		local lastcol = finish[2]
		if lastcol == 2147483647 then
			lastcol = -1
		else
			lastcol = lastcol + 1
		end
		local block = {}
		for _, line in ipairs(lines) do
			table.insert(block, line:sub(firstcol, lastcol))
		end
		result = fn(block, mode)
		-- If I take the result being nil as leaving it unmodified, then I can use it
		-- to skip the set part and reuse this just to get fed the input.
		if result == nil then
			return
		end

		if #result == 0 then
			result = {''}
		end
		for i, line in ipairs(lines) do
			local result_index = (i-1) % #result + 1
			local replacement = result[result_index]
			lines[i] = table.concat {line:sub(1, firstcol-1), replacement, line:sub(lastcol+1)}
		end
		result = lines
	end

	return api.nvim_buf_set_lines(buf, start[1] - 1, finish[1], false, result)
end

-- Equivalent to `echo vim.inspect(...)`
function nvim_print(...)
  if select("#", ...) == 1 then
    api.nvim_out_write(vim.inspect((...)))
  else
    api.nvim_out_write(vim.inspect {...})
  end
  api.nvim_out_write("\n")
end

--- Equivalent to `echo` EX command
function nvim_echo(...)
  for i = 1, select("#", ...) do
    local part = select(i, ...)
    api.nvim_out_write(tostring(part))
    -- api.nvim_out_write("\n")
    api.nvim_out_write(" ")
  end
	api.nvim_out_write("\n")
end

-- `nvim.$method(...)` redirects to `vim.api.nvim_$method(...)`
-- `nvim.fn.$method(...)` redirects to `vim.api.nvim_call_function($method, {...})`
-- TODO `nvim.ex.$command(...)` is approximately `:$command {...}.join(" ")`
-- `nvim.print(...)` is approximately `echo vim.inspect(...)`
-- `nvim.echo(...)` is approximately `echo table.concat({...}, '\n')`
-- Both methods cache the inital lookup in the metatable, but there is a small overhead regardless.
nvim = setmetatable({
  print = nvim_print;
  echo = nvim_echo;
  fn = setmetatable({}, {
    __index = function(self, k)
      local mt = getmetatable(self)
      local x = mt[k]
      if x ~= nil then
        return x
      end
      local f = function(...) return api.nvim_call_function(k, {...}) end
      mt[k] = f
      return f
    end
  });
  buf = setmetatable({
			-- current = setmetatable({}, {
			-- 	__index = function(self, k)
			-- 		local mt = getmetatable(self)
			-- 		local x = mt[k]
			-- 		if x ~= nil then
			-- 			return x
			-- 		end
			-- 		local command = k:gsub("_$", "!")
			-- 		local f = function(...) return vim.api.nvim_command(command.." "..table.concat({...}, " ")) end
			-- 		mt[k] = f
			-- 		return f
			-- 	end
			-- });
		}, {
    __index = function(self, k)
      local mt = getmetatable(self)
      local x = mt[k]
      if x ~= nil then
        return x
      end
			local f = api['nvim_buf_'..k]
      mt[k] = f
      return f
    end
  });
  ex = setmetatable({}, {
    __index = function(self, k)
      local mt = getmetatable(self)
      local x = mt[k]
      if x ~= nil then
        return x
      end
			local command = k:gsub("_$", "!")
      local f = function(...)
				return api.nvim_command(table.concat(vim.tbl_flatten {command, ...}, " "))
			end
      mt[k] = f
      return f
    end
  });
  g = setmetatable({}, {
    __index = function(_, k)
			return api.nvim_get_var(k)
		end;
    __newindex = function(_, k, v)
			if v == nil then
				return api.nvim_del_var(k)
			else
				return api.nvim_set_var(k, v)
			end
		end;
  });
  v = setmetatable({}, {
    __index = function(_, k)
			return api.nvim_get_vvar(k)
		end;
    __newindex = function(_, k, v)
			return api.nvim_set_vvar(k, v)
    end
  });
  b = setmetatable({}, {
    __index = function(_, k)
			return api.nvim_buf_get_var(0, k)
		end;
    __newindex = function(_, k, v)
			if v == nil then
				return api.nvim_buf_del_var(0, k)
			else
				return api.nvim_buf_set_var(0, k, v)
			end
    end
  });
  o = setmetatable({}, {
    __index = function(_, k)
			return api.nvim_get_option(k)
		end;
    __newindex = function(_, k, v)
			return api.nvim_set_option(k, v)
    end
  });
  bo = setmetatable({}, {
    __index = function(_, k)
			return api.nvim_buf_get_option(0, k)
		end;
    __newindex = function(_, k, v)
			return api.nvim_buf_set_option(0, k, v)
    end
  });
  env = setmetatable({}, {
    __index = function(_, k)
			return api.nvim_call_function('getenv', {k})
		end;
    __newindex = function(_, k, v)
			return api.nvim_call_function('setenv', {k, v})
    end
  });
}, {
  __index = function(self, k)
    local mt = getmetatable(self)
    local x = mt[k]
    if x ~= nil then
      return x
    end
    local f = api['nvim_'..k]
    mt[k] = f
    return f
  end
})

nvim.option = nvim.o

---
-- Higher level text manipulation utilities
---

function nvim_set_selection_lines(lines)
	return nvim_buf_set_region_lines(nil, '<', '>', VISUAL_MODE.line, lines)
end

-- Return the selection as a string
-- RETURNS: string
function nvim_selection(mode)
	return table.concat(nvim_buf_get_region_lines(nil, '<', '>', mode or VISUAL_MODE.char), "\n")
end

-- TODO Use iskeyword
-- WORD_PATTERN = "[%w_]"

-- -- TODO accept buf or win as arguments?
-- function nvim_transform_cword(fn)
-- 	-- lua nvim_print(nvim.win_get_cursor(nvim.get_current_win()))
-- 	local win = api.nvim_get_current_win()
-- 	local row, col = unpack(api.nvim_win_get_cursor(win))
-- 	local buf = api.nvim_get_current_buf()
-- 	-- local row, col = unpack(api.nvim_buf_get_mark(buf, '.'))
-- 	local line = nvim_buf_get_region_lines(buf, row, row, VISUAL_MODE.line)[1]
-- 	local start_idx, end_idx
-- 	_, end_idx = line:find("^[%w_]+", col+1)
-- 	end_idx = end_idx or (col + 1)
-- 	if line:sub(col+1, col+1):match("[%w_]") then
-- 		_, start_idx = line:sub(1, col+1):reverse():find("^[%w_]+")
-- 		start_idx = col + 1 - (start_idx - 1)
-- 	else
-- 		start_idx = col + 1
-- 	end
-- 	local fragment = fn(line:sub(start_idx, end_idx))
-- 	local new_line = line:sub(1, start_idx-1)..fragment..line:sub(end_idx+1)
-- 	nvim_buf_set_region_lines(buf, row, row, VISUAL_MODE.line, {new_line})
-- end

-- Necessary glue for nvim_text_operator
-- Calls the lua function whose name is g:lua_fn_name and forwards its arguments
vim.api.nvim_command [[
function! LuaExprCallback(...) abort
	return luaeval(g:lua_expr, a:000)
endfunction
]]

function nvim_text_operator(fn)
	LUA_FUNCTION = fn
	nvim.g.lua_expr = 'LUA_FUNCTION(_A[1])'
	api.nvim_set_option('opfunc', 'LuaExprCallback')
	-- api.nvim_set_option('opfunc', 'v:lua.LUA_FUNCTION')
	api.nvim_feedkeys('g@', 'ni', false)
end

function nvim_text_operator_transform_selection(fn, forced_visual_mode)
	return nvim_text_operator(function(visualmode)
		nvim_buf_transform_region_lines(nil, "[", "]", forced_visual_mode or visualmode, function(lines)
			return fn(lines, visualmode)
		end)
	end)
end

function nvim_visual_mode()
	local visualmode = nvim.fn.visualmode()
	if visualmode == 'v' then
		return VISUAL_MODE.char
	elseif visualmode == 'V' then
		return VISUAL_MODE.line
	else
		return VISUAL_MODE.block
	end
end

function nvim_transform_cword(fn)
	nvim_text_operator_transform_selection(function(lines)
		return {fn(lines[1])}
	end)
	api.nvim_feedkeys('iw', 'ni', false)
end

function nvim_transform_cWORD(fn)
	nvim_text_operator_transform_selection(function(lines)
		return {fn(lines[1])}
	end)
	api.nvim_feedkeys('iW', 'ni', false)
end

function nvim_source_current_buffer()
	loadstring(table.concat(nvim_buf_get_region_lines(nil, 1, -1, VISUAL_MODE.line), '\n'))()
end

LUA_MAPPING = {}
LUA_BUFFER_MAPPING = {}

local function escape_keymap(key)
	-- Prepend with a letter so it can be used as a dictionary key
	return 'k'..key:gsub('.', string.byte)
end

local valid_modes = {
	n = 'n'; v = 'v'; x = 'x'; i = 'i';
	o = 'o'; t = 't'; c = 'c'; s = 's';
	-- :map! and :map
	['!'] = '!'; [' '] = '';
}

-- TODO(ashkan) @feature Disable noremap if the rhs starts with <Plug>
function nvim_apply_mappings(mappings, default_options)
	-- May or may not be used.
	local current_bufnr = api.nvim_get_current_buf()
	for key, options in pairs(mappings) do
		options = vim.tbl_extend("keep", options, default_options or {})
		local bufnr = current_bufnr
		-- TODO allow passing bufnr through options.buffer?
		-- protect against specifying 0, since it denotes current buffer in api by convention
		if type(options.buffer) == 'number' and options.buffer ~= 0 then
			bufnr = options.buffer
		end
		local mode, mapping = key:match("^(.)(.+)$")
		if not mode then
			assert(false, "nvim_apply_mappings: invalid mode specified for keymapping "..key)
		end
		if not valid_modes[mode] then
			assert(false, "nvim_apply_mappings: invalid mode specified for keymapping. mode="..mode)
		end
		mode = valid_modes[mode]
		local rhs = options[1]
		-- Remove this because we're going to pass it straight to nvim_set_keymap
		options[1] = nil
		if type(rhs) == 'function' then
			-- Use a value that won't be misinterpreted below since special keys
			-- like <CR> can be in key, and escaping those isn't easy.
			local escaped = escape_keymap(key)
			local key_mapping
			if options.dot_repeat then
				local key_function = rhs
				rhs = function()
					key_function()
					-- -- local repeat_expr = key_mapping
					-- local repeat_expr = mapping
					-- repeat_expr = api.nvim_replace_termcodes(repeat_expr, true, true, true)
					-- nvim.fn["repeat#set"](repeat_expr, nvim.v.count)
					nvim.fn["repeat#set"](nvim.replace_termcodes(key_mapping, true, true, true), nvim.v.count)
				end
				options.dot_repeat = nil
			end
			if options.buffer then
				-- Initialize and establish cleanup
				if not LUA_BUFFER_MAPPING[bufnr] then
					LUA_BUFFER_MAPPING[bufnr] = {}
					-- Clean up our resources.
					api.nvim_buf_attach(bufnr, false, {
						on_detach = function()
							LUA_BUFFER_MAPPING[bufnr] = nil
						end
					})
				end
				LUA_BUFFER_MAPPING[bufnr][escaped] = rhs
				-- TODO HACK figure out why <Cmd> doesn't work in visual mode.
				if mode == "x" or mode == "v" then
					key_mapping = (":<C-u>lua LUA_BUFFER_MAPPING[%d].%s()<CR>"):format(bufnr, escaped)
				else
					key_mapping = ("<Cmd>lua LUA_BUFFER_MAPPING[%d].%s()<CR>"):format(bufnr, escaped)
				end
			else
				LUA_MAPPING[escaped] = rhs
				-- TODO HACK figure out why <Cmd> doesn't work in visual mode.
				if mode == "x" or mode == "v" then
					key_mapping = (":<C-u>lua LUA_MAPPING.%s()<CR>"):format(escaped)
				else
					key_mapping = ("<Cmd>lua LUA_MAPPING.%s()<CR>"):format(escaped)
				end
			end
			rhs = key_mapping
			options.noremap = true
			options.silent = true
		end
		if options.buffer then
			options.buffer = nil
			api.nvim_buf_set_keymap(bufnr, mode, mapping, rhs, options)
		else
			api.nvim_set_keymap(mode, mapping, rhs, options)
		end
	end
end

function nvim_create_augroups(definitions)
	for group_name, definition in pairs(definitions) do
		api.nvim_command('augroup '..group_name)
		api.nvim_command('autocmd!')
		for _, def in ipairs(definition) do
			-- if type(def) == 'table' and type(def[#def]) == 'function' then
			-- 	def[#def] = lua_callback(def[#def])
			-- end
			local command = table.concat(vim.tbl_flatten{'autocmd', def}, ' ')
			api.nvim_command(command)
		end
		api.nvim_command('augroup END')
	end
end

--- Highlight a region in a buffer from the attributes specified
function nvim_highlight_region(buf, ns, highlight_name,
		 region_line_start, region_byte_start,
		 region_line_end, region_byte_end)
	if region_line_start == region_line_end then
		api.nvim_buf_add_highlight(buf, ns, highlight_name, region_line_start, region_byte_start, region_byte_end)
	else
		api.nvim_buf_add_highlight(buf, ns, highlight_name, region_line_start, region_byte_start, -1)
		for linenum = region_line_start + 1, region_line_end - 1 do
			api.nvim_buf_add_highlight(buf, ns, highlight_name, linenum, 0, -1)
		end
		api.nvim_buf_add_highlight(buf, ns, highlight_name, region_line_end, 0, region_byte_end)
	end
end


---
-- Things Lua should've had
---

function string.startswith(s, n)
	return s:sub(1, #n) == n
end

function string.endswith(self, str)
  return self:sub(-#str) == str
end

---
-- SPAWN UTILS
---

local function clean_handles()
	local n = 1
	while n <= #HANDLES do
		if HANDLES[n]:is_closing() then
			table.remove(HANDLES, n)
		else
			n = n + 1
		end
	end
end

HANDLES = {}

function spawn(cmd, params, onexit)
	local handle, pid
	handle, pid = vim.loop.spawn(cmd, params, function(code, signal)
		if type(onexit) == 'function' then onexit(code, signal) end
		handle:close()
		clean_handles()
	end)
	table.insert(HANDLES, handle)
	return handle, pid
end

--- MISC UTILS

function epoch_ms()
	local s, ns = vim.loop.gettimeofday()
	return s * 1000 + math.floor(ns / 1000)
end

function epoch_ns()
	local s, ns = vim.loop.gettimeofday()
	return s * 1000000 + ns
end


