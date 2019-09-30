-- loadfile('/home/ashkan/.config/nvim/lua/nvim_utils.lua')()
require 'nvim_utils'

---
-- CORE UTILITIES
---
-- These are the minimum core functions for parsing and manipulating todo lines which can be used
-- to create user specific mappings and actions later on.

-- A list of entries which are not to be considered as tags, such as protocol prefixes
-- e.g. http://... would be considered a tag.
TODO_TAG_BLOCKLIST = { http = true, https = true, git = true, zephyr = true, ftp = true, sftp = true }

function todo_extract_tags(body)
	local tags = {}
	local function inserter(k, v)
		if not TODO_TAG_BLOCKLIST[k] then
			tags[k] = v
			return ""
		end
	end
	body = body:gsub(" ([%w%-_:]-):(%S+)", inserter)
	body = body:gsub("^([%w%-_:]-):(%S+) ?", inserter)
	return tags, body
end

function todo_extract_projects(body)
	local projects = {}
	local function inserter(v)
		table.insert(projects, v)
		return ""
	end
	body = body:gsub(" (%+%S+)", inserter)
	body = body:gsub("^(%+%S+) ?", inserter)
	return projects, body
end

function todo_extract_contexts(body)
	local contexts = {}
	local function inserter(v)
		table.insert(contexts, v)
		return ""
	end
	body = body:gsub(" (@%S+)", inserter)
	body = body:gsub("^(@%S+) ?", inserter)
	return contexts, body
end

function todo_parse(line)
  local is_completed
  line = line:gsub("^x ", function(v) is_completed = true; return "" end)
  local priority
  line = line:gsub("^(%([A-Z]%)) ", function(v) priority = v; return "" end)
  local date1
  line = line:gsub("^(%d%d%d%d%-%d%d?%-%d%d?) ", function(v) date1 = v; return "" end)
  local date2
  line = line:gsub("^(%d%d%d%d%-%d%d?%-%d%d?) ", function(v) date2 = v; return "" end)
  local creation, completion
  if date1 then
    if date2 then
      -- TODO sort these to assert their identity
      creation, completion = date2, date1
    else
      creation = date1
    end
  end

  return {
    is_completed = is_completed;
    priority = priority;
    creation = creation;
    completion = completion;
    body = line;
    projects = todo_extract_projects(line);
    contexts = todo_extract_contexts(line);
    tags = todo_extract_tags(line);
  }
end

function todo_parse_if_not_parsed(input)
  if type(input) == 'string' then
    return todo_parse(input)
  end
  return input
end

function todo_set_completion_date(input)
  local parsed = todo_parse_if_not_parsed(input)
  local parts = {}
  if parsed.is_completed then
    if parsed.priority   then table.insert(parts, parsed.priority)   end
    if parsed.creation   then table.insert(parts, parsed.creation)   end
  else
    table.insert(parts, "x")
    if parsed.priority then table.insert(parts, parsed.priority)   end
    if parsed.creation then
      table.insert(parts, os.date("%Y-%m-%d"))
      table.insert(parts, parsed.creation)
    end
  end
  table.insert(parts, parsed.body)
  return table.concat(parts, " ")
end

function todo_format_prefix(parsed)
  local parts = {}
  if parsed.is_completed then table.insert(parts, "x") end
  if parsed.priority     then table.insert(parts, parsed.priority) end
  if parsed.completion   then table.insert(parts, parsed.completion) end
  if parsed.creation     then table.insert(parts, parsed.creation) end
  return table.concat(parts, " ")
end

function todo_set_end_date_for_tag(input, tag)
  local parsed = todo_parse_if_not_parsed(input)
  if tag:match("start$") then
    local endtag = tag:gsub("start$", "end")
    if not parsed.tags[endtag] then
      parsed.tags[endtag] = os.date("%Y-%m-%dT%T%Z")
    end
  end
  return todo_format(parsed)
end

function todo_format(input, extra)
  local parsed = todo_parse_if_not_parsed(input)
  local parts = {}
  -- prefix
  do
    local prefix = todo_format_prefix(parsed)
    if #prefix > 0 then
      table.insert(parts, prefix)
    end
  end

	local tags, projects, contexts

	-- body
	local body = parsed.body
	tags, body = todo_extract_tags(body)
	if extra and extra.projects then projects, body = todo_extract_projects(body) end
	if extra and extra.contexts then contexts, body = todo_extract_contexts(body) end
	body = vim.trim(body)
	if #body > 0 then
		table.insert(parts, body)
	end

	if projects then
		table.sort(projects)
		parts = vim.tbl_flatten {parts, projects}
	end

	if contexts then
		table.sort(contexts)
		parts = vim.tbl_flatten {parts, contexts}
	end

  -- tags
  do
    local keys = {}
    for k, _ in pairs(parsed.tags) do
      table.insert(keys, k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local v = parsed.tags[k]
      table.insert(parts, table.concat({k, v}, ":"))
    end
  end
  return table.concat(parts, " ")
end

function compare_lists(a, b)
	for i = 1,math.min(#a, #b) do
		if a[i] < b[i] then
			return true
		elseif a[i] > b[i] then
			return false
		end
	end
	if #a < #b then
		return true
	end
	return false
end

function tbl_remove_dups(a, b)
	-- TODO @performance could be improved
	local duplicates = {}
	for _, v in ipairs(a) do
		duplicates[v] = (duplicates[v] or 0) + 1
	end
	for _, v in ipairs(b) do
		duplicates[v] = (duplicates[v] or 0) + 1
	end
	local left = {}
	for _, v in ipairs(a) do
		if not (duplicates[v] and duplicates[v] > 1) then
			table.insert(left, v)
		end
	end
	local right = {}
	for _, v in ipairs(b) do
		if not (duplicates[v] and duplicates[v] > 1) then
			table.insert(right, v)
		end
	end
	return left, right
end

function todo_sort_lines(lines)
	for i, line in ipairs(lines) do
		lines[i] = {line, todo_parse(line)}
	end
	table.sort(lines, function(a, b)
		a, b = a[2], b[2]
		-- TODO @performance could be improved
		local contexts_a, contexts_b = tbl_remove_dups(a.contexts or {}, b.contexts or {})
		local projects_a, projects_b = tbl_remove_dups(a.projects or {}, b.projects or {})
		return compare_lists(
			vim.tbl_flatten {a.is_completed and 2 or 1, (a.priority or "(Z)"), a.tags.due or "9999-99-99", contexts_a, projects_a, a.body},
			vim.tbl_flatten {b.is_completed and 2 or 1, (b.priority or "(Z)"), b.tags.due or "9999-99-99", contexts_b, projects_b, b.body}
		)
		-- return (a[2].contexts[1] or "") < (b[2].contexts[1] or "")
	end)
	for i, line in ipairs(lines) do
		lines[i] = line[1]
	end
	return lines
end

---
-- MAPPINGS
---

function todo_open_context(line)
  local parsed = todo_parse_if_not_parsed(line)
  local context = parsed.contexts[1]
  if context then
    if context:match("%.todo$") then
      nvim.ex.edit("%:h/"..context:sub(2))
    end
  end
end

function todo_action_open_project(line)
  local parsed = todo_parse_if_not_parsed(line)
  local project = parsed.projects[1]
  if project then
    if project:match("%.todo$") then
      nvim.ex.edit("%:h/"..project:sub(2))
    end
  end
end

function todo_action_try_open_cword()
  -- if nvim.fn.expand("<cWORD>"):sub(1,1) == "@"then
  local cword = nvim.fn.expand("<cWORD>")
  if cword:sub(1,1) == "+" then
    nvim.ex.edit("%:h/"..nvim.fn.expand(cword:sub(2)))
  else
    nvim.ex.norm_("gf")
  end
end

function todo_reformat(lines, extra)
  lines = todo_sort_lines(lines)
  for i, line in ipairs(lines) do
    lines[i] = todo_format(line, extra)
  end
	return lines
end

function todo_filter(lines, filterfn)
  local result = {}
  for _, line in ipairs(lines) do
    local parsed = todo_parse(line)
    if filterfn(parsed) then
      table.insert(result, line)
    end
  end
  return result
end

-- function todo_create_filter_from_this(cword)
local function todo_create_filter_from_this(cword)
  local ctype = cword:sub(1,1)
  if ctype == "@" then
    -- TODO trim?
    return function(p) return vim.tbl_contains(p.contexts, cword) end
  elseif ctype == "+" then
    return function(p) return vim.tbl_contains(p.projects, cword) end
  end
  return function(p) return true end
end

-- TODO rename other functions to match this pattern where functions which are expected
-- to be interface with mappings directly are called *_action_*
function todo_action_filter(mark_a, mark_b)
  assert(false, "unimplemented")
end

function todo_action_reformat(is_visual_mode)
	local function reformat(lines)
		return todo_reformat(lines, nvim.g.todo_format_settings or {})
	end
	if is_visual_mode then
		nvim_buf_transform_region_lines(nil, '<', '>', VISUAL_MODE.line, reformat)
	else
		nvim_text_operator_transform_selection(reformat, VISUAL_MODE.line)
	end
end

function todo_action_filter_by_cword(is_visual_mode)
	local filterfn = todo_create_filter_from_this(nvim.fn.expand("<cWORD>"))
	local function filter(lines)
		return todo_filter(lines, filterfn)
	end
	if is_visual_mode then
		nvim_buf_transform_region_lines(nil, '<', '>', VISUAL_MODE.line, filter)
	else
		nvim_text_operator_transform_selection(filter, VISUAL_MODE.line)
	end
end

function todo_action_set_end_date_for_tag_by_cword(line)
	local tag = nvim.fn.expand("<cWORD>"):match("^[^:]+")
	return todo_set_end_date_for_tag(line, tag)
end

return {
	["ngf"]  = { "<Cmd>lua todo_action_try_open_cword()<CR>",                 noremap = true; };

	["n AO"] = { "<Cmd>.luado todo_action_open_project(line)<CR>",            noremap = true; };

	["n af"] = { "<Cmd>lua todo_action_reformat(false)<CR>",                  noremap = true; };
	["x af"] = { ":lua todo_action_reformat(true)<CR>",                       noremap = true; };

	-- " TODO change AF to mean filter, which will look at cWORD and create a new
	-- " buffer which has the lines with that context/project @feature
	-- " Make sure to make the buffer unmodified like zephyr does on creation
	["n AF"] = { "<Cmd>lua todo_action_filter_by_cword(false)<CR>",           noremap = true; };
	["x AF"] = { ":lua todo_action_filter_by_cword(true)<CR>",                noremap = true; };
	-- ["n AF"] = { [[<Cmd>%luado return todo_filter({line}, todo_create_filter_from_this(nvim.fn.expand("<cWORD>")))[1] or ""<CR>]],           noremap = true; };

	["n AE"] = { "<Cmd>.luado todo_action_set_end_date_for_tag_by_cword<CR>", noremap = true; };

	["n AC"] = { "<Cmd>.luado return todo_set_completion_date(line)<CR>",     noremap = true; };
	["x AC"] = { ":luado return todo_set_completion_date(line)<CR>",          noremap = true; };
}
