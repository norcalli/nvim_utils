# nvim_utils.lua

This is a copy of my progress migrating my init.vim to init.lua.

The main utility here is `nvim_utils.lua`, and everything else is just an example of how
I use it.

This utility can be installed with any plugin manager, presumably, such as:

```
Plug 'norcalli/nvim_utils'
```

# Example

```lua
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
    nvim_text_operator_transform_selection(replace)
  end
end

local text_object_mappings = {
	["n xr"]  = { [[<Cmd>lua text_object_replace(false)<CR>]],               noremap = true; };
	["x xr"]  = { [[:lua text_object_replace(true)<CR>]],                    noremap = true; };
	["oil"]   = { [[<Cmd>normal! $v^<CR>]],  noremap = true; };
	["xil"]   = { [[<Cmd>normal! $v^<CR>]],  noremap = true; };
}

local other_mappings = {
	["nY"] = { [["+y]], noremap = true; };
	["xY"] = { [["+y]], noremap = true; };
	-- Highlight current cword
	["n[,"]  = { function()
		-- \C forces matching exact case
		-- \M forces nomagic interpretation
		-- \< and \> denote whole word match
		nvim.fn.setreg("/", ([[\C\M\<%s\>]]):format(nvim.fn.expand("<cword>")), "c")
		nvim.o.hlsearch = true
	end };
	["i<c-a>"] = { function()
		local pos = nvim.win_get_cursor(0)
		local line = nvim.buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
		local _, start = line:find("^%s+")
		nvim.win_set_cursor(0, {pos[1], start})
	end };
}

local mappings = {
	text_object_mappings,
	other_mappings,
}

nvim_apply_mappings(vim.tbl_extend("error", unpack(mappings)), default_options)

FILETYPE_HOOKS = {
	todo = function()
		nvim.command('setl foldlevel=2')
		nvim_apply_mappings(todo_mappings, { buffer = true })
	end;
}


local autocmds = {
	todo = {
		{"BufEnter",     "*.todo", "setl ft=todo"};
		{"FileType",     "todo",   "lua FILETYPE_HOOKS.todo()"};
	};
}

nvim_create_augroups(autocmds)
```


# Things `nvim_utils` provides

There are two types of things provided:

- `nvim` is an object which contains shortcut/magic methods that are very useful for mappings
- `nvim_*` functions which constitute building blocks for APIs like text operators or text manipulation or mappings

## Constants

- `VISUAL_MODE.{line,char,block}`

## API Function and Command Shortcuts

All of these methods cache the inital lookup in the metatable, but there is a small overhead regardless.

- `nvim.$method(...)` redirects to `vim.api.nvim_$method(...)`
	- e.g. `nvim.command(...) == vim.api.nvim_command(...)`.
	- This is just for laziness.
- `nvim.fn.$method(...)` redirects to `vim.api.nvim_call_function($method, {...})`
	- e.g. `nvim.fn.expand("%:h")` or `nvim.fn.has("terminal")`
- `nvim.ex.$command(...)` is approximately `:$command flatten({...}).join(" ")`
	- e.g. `nvim.ex.edit("term://$SHELL")` or `nvim.ex.startinsert()`
	- Since `!` isn't a valid identifier character, you can use `_` at the end to indicate a `!`
		- e.g. `nvim.ex.nnoremap_("x", "<Cmd>echo hi<CR>")`

## Variable shortcuts

- `nvim.g` can be used to get/set `g:` global variables.
	- e.g. `nvim.g.variable == g:variable`
	- `nvim.g.variable = 123` or `nvim.g.variable = nil` to delete the variable
	- `:h nvim_get_var` `:h nvim_set_var` `:h nvim_del_var` for more
- `nvim.v` can be used to get/set `v:` variables.
	- e.g. `nvim.v.count1 == v:count1`
	- Useful `v:` variables, `v:register`, `v:count1`, etc..
	- `nvim.v.variable = 123` to set the value (when not read-only).
	- `:h nvim_get_vvar` `:h nvim_set_vvar` for more
- `nvim.b` can be used to get/set `b:` buffer variables for the current buffer.
	- e.g. `nvim.b.variable == b:variable`
	- `nvim.b.variable = 123` or `nvim.b.variable = nil` to delete the variable
	- `:h nvim_buf_get_var` `:h nvim_buf_set_var` `:h nvim_buf_del_var` for more
- `nvim.env` can be used to get/set environment variables.
	- e.g. `nvim.env.PWD == $PWD`
	- `nvim.env.TEST = 123` to set the value. Equivalent to `let $TEST = 123`.
	- `:h setreg` `:h setreg` for more. These aren't API functions.
- `nvim.o` can be used to get/set global options, as in `:h options` which are set through `set`.
	- e.g. `nvim.o.shiftwidth == &shiftwidth`
	- `nvim.o.shiftwidth = 8` is equivalent to `set shiftwidth=8` or `let &shiftwidth = 8`
	- `:h nvim_get_option` `:h nvim_set_option` for more.
- `nvim.bo` can be used to get/set **buffer** options, as in `:h options` which are set through `setlocal`.
	- Only for the current buffer.
	- e.g. `nvim.bo.shiftwidth == &shiftwidth`
	- `nvim.bo.shiftwidth = 8` is equivalent to `setlocal shiftwidth=8`
	- `:h nvim_buf_get_option` `:h nvim_buf_set_option` for more.

## Extra API functions

- `nvim_mark_or_index(buf, input)`: An enhanced version of nvim_buf_get_mark which also accepts:
	- A number as input: which is taken as a line number.
	- A pair, which is validated and passed through otherwise.
- `nvim_buf_get_region_lines(buf, mark_a, mark_b, mode)`: Return the lines of the selection, respecting selection modes.
	- `buf` defaults to current buffer. `mark_a` defaults to `'<'`. `mark_b` defaults to `'>'`. `mode` defaults to `VISUAL_MODE.char`
	- `block` isn't implemented because I haven't gotten around to it yet.
	- Accepts all forms of input that `nvim_mark_or_index` accepts for `mark_a`/`mark_b`.
	- Returns a `List`.
- `nvim_buf_set_region_lines(buf, mark_a, mark_b, mode, lines)`: Set the lines between the marks.
	- `buf` defaults to current buffer. `mark_a` defaults to `'<'`. `mark_b` defaults to `'>'`.
	- `lines` is a `List`. Can be greater or less than the number of lines in the region. It will add or delete lines.
	- Only `line` is currently implemented. This is because to support `char`, you must have knowledge of the existing lines, and
	I wasn't going to do potentially expensive operations with a hidden cost.
	- If you want to use `char` mode, you want to use `nvim_buf_transform_region_lines` instead.
	- Accepts all forms of input that `nvim_mark_or_index` accepts for `mark_a`/`mark_b`.
- `nvim_buf_transform_region_lines(buf, mark_a, mark_b, mode, fn)`: Transform the lines by calling `fn(lines, visualmode) -> lines`.
	- `buf` defaults to current buffer. `mark_a` defaults to `'<'`. `mark_b` defaults to `'>'`.
	- `block` isn't implemented because I haven't gotten around to it yet.
	- `fn(lines, visualmode)` should return a list of lines to set in the region.
	- A result of `nil` will not modify the region.
	- A result of `{}` will be changed to `{""}` which empties the region.
	- Accepts all forms of input that `nvim_mark_or_index` accepts for `mark_a`/`mark_b`.
- `nvim_set_selection_lines(lines)`: Literally just a shortcut to `nvim_buf_set_region_lines(0, '<', '>', VISUAL_MODE.line, lines)`
- `nvim_selection(mode)`
	- `return table.concat(nvim_buf_get_region_lines(nil, '<', '>', mode or VISUAL_MODE.char), "\n")`
- `nvim_text_operator(fn)`: Pass in a callback which will be called like `opfunc` is for `g@` text operators.
	- `fn(visualmode)` is the format. This doesn't receive any lines, so you can do anything here.
	- If you didn't know about text operators, I suggest `:h g@`. It sets the region described by motion following `g@` to `'[,']`
	- For example
```lua
nvim_text_operator(function(visualmode)
	nvim_print(visualmode, nvim_mark_or_index('['), nvim_mark_or_index(']'))
end)
```
- `nvim_text_operator_transform_selection(fn, force_visual_mode)`: Just like `nvim_text_operator`, but different.
	- `fn(lines, visualmode) -> lines` is the expected format for lines.
	- `force_visual_mode` can be used to override the visualmode from `nvim_text_operator`
	- Here's the definition
```lua
function nvim_text_operator_transform_selection(fn, forced_visual_mode)
	return nvim_text_operator(function(visualmode)
		nvim_buf_transform_region_lines(nil, "[", "]", forced_visual_mode or visualmode, function(lines)
			return fn(lines, visualmode)
		end)
	end)
end
```
- `nvim_visual_mode()`: calls `visualmode()` but returns one of `VISUAL_MODE` entries instead of `v, V, etc..`
- `nvim_transform_cword(fn)`: self explanatory
- `nvim_transform_cWORD(fn)`: self explanatory
- `nvim_apply_mappings(mappings, default_options)`
	- `mappings` should be a dictionary.
	- The keys of mapping should start with the type of mapping, e.g. `n` for `normal`, `x` for `xmap`, `v` for `vmap`, `!` for `map!`, `o` for `omap` etc. The rest of the key is the mapping for that mode.
		- e.g. `n xr` is `nmap <space>xr`. `o<CR>` is `omap <CR>` etc.
	- The values should start with the value of the mapping, which is a string or a Lua function.
	- The rest of it are options like `silent`, `expr`, `nowait`, `unique`, or `buffer`
	- I implemented `buffer` support myself. I also implemented the Lua callback support.
		- You can peek at how this is done by `nvim_print(LUA_MAPPING, LUA_BUFFER_MAPPING)`
	- For a lot of examples, look at `example_dotfiles/init.lua:82`.
	- Example:
```lua
local mappings = {
	["n af"] = { "<Cmd>RustFmt<CR>", noremap = true; };
	["x af"] = { ":RustFmtRange<CR>", noremap = true; };
	["n AZ"] = { function() nvim_print("hi") end };
}
nvim_apply_mappings(mappings, { buffer = true; silent = true; })
```
- `nvim_create_augroups(definitions)`
	- `definitions` is a map of lists
```lua
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
nvim_create_augroups(autocmds)
```

## Additional functionality

### Utilities

- `nvim_print(...)` is approximately `echo vim.inspect({...})`
	- it's also defined at `nvim.print`
	- This is useful for debugging. It can accept multiple arguments.
- `nvim_echo(...)` is approximately `echo table.concat({...}, '\n')`
	- it's also defined at `nvim.echo`
	- It can accept multiple arguments and concatenates them with a space.

### Things Lua is missing

- `string.startswith`
- `string.endswith`
