local M = {}

local api = vim.api
local config = require('drex.config').config

-- ###############################################
-- ### string utility
-- ###############################################

---Check if the given `str` starts with `start`
---@param str string
---@param start string
---@return boolean
function M.starts_with(str, start)
    return str:sub(1, #start) == start
end

---Check if the given `str` ends with `ending`
---@param str string
---@param ending string
---@return boolean
function M.ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

---Escape `str` for the usage in Lua pattern matching
---@param str string String to escape
---@return string
function M.escape(str)
    return (str:gsub('%%', '%%%%')
               :gsub('^%^', '%%^')
               :gsub('%$$', '%%$')
               :gsub('%(', '%%(')
               :gsub('%)', '%%)')
               :gsub('%.', '%%.')
               :gsub('%[', '%%[')
               :gsub('%]', '%%]')
               :gsub('%*', '%%*')
               :gsub('%+', '%%+')
               :gsub('%-', '%%-')
               :gsub('%?', '%%?'))
end

---Escape `str` for the usage in a VIM regex
---@param str string String to escape
---@return string
function M.vim_escape(str)
    return str:gsub('\\', '\\\\')
              :gsub('~', '\\~')
              :gsub('*', '\\*')
              :gsub('%[', '\\[')
              :gsub('%]', '\\]')
              :gsub('%.', '\\.')
end

-- ###############################################
-- ### line utility
-- ###############################################

-- should be '/' for linux/osx or '\' for windows
M.path_separator = package.config:sub(1, 1)

-- group 1: indentation
-- group 2: icon
-- group 3: element (path + name)
-- group 4: path
-- group 5: name
local line_pattern = string.gsub('^(%s*)([^%s/]+) ((.*/)(.*))$', '/', M.path_separator)

---Extract the file/directory icon from a `line`
---
---Examples:
---<pre>
---| Input                          | Output |
---|--------------------------------|--------|
---| " + /home/user"                | "+"    |
---| "   · /home/user/example.json" | "·"    |
---</pre>
---@param line string The line string to operate on
---@return string
function M.get_icon(line)
    local _, icon = line:match(line_pattern)
    return icon
end

---Extract the elements path from a `line`
---
---Examples:
---<pre>
---| Input                          | Output        |
---|--------------------------------|---------------|
---| " + /home/user"                | "/home/"      |
---| "   · /home/user/example.json" | "/home/user/" |
---</pre>
---@param line string The line string to operate on
---@return string
function M.get_path(line)
    local _, _, _, path = line:match(line_pattern)
    return path
end

---Extract the elements name from a `line`
---
---Examples:
---<pre>
---| Input                          | Output         |
---|--------------------------------|----------------|
---| " + /home/user"                | "user"         |
---| "   · /home/user/example.json" | "example.json" |
---</pre>
---@param line string The line string to operate on
---@return string
function M.get_name(line)
    local _, _, _, _, name = line:match(line_pattern)
    return name
end

---Extract the complete element from a `line`
---
---Examples:
---<pre>
---| Input                          | Output                    |
---|--------------------------------|---------------------------|
---| " + /home/user"                | "/home/user"              |
---| "   · /home/user/example.json" | "/home/user/example.json" |
---</pre>
---@param line string The line string to operate on
---@return string
function M.get_element(line)
    local _, _, element = line:match(line_pattern)
    return element
end

---Checks the configured directory icons to see if the element on `line` is a directory
---@param line string The line to operate on
---@return boolean
function M.is_directory(line)
    local icon = M.get_icon(line)
    return icon == config.icons.dir_open or icon == config.icons.dir_closed
end

---Checks the configured directory icons to see if the element on `line` is an open directory
---@param line string The line to operate on
---@return boolean
function M.is_open_directory(line)
    return M.get_icon(line) == config.icons.dir_open
end

---Checks the configured directory icons to see of the element on `line` is a closed directory
---@param line string The line to operate on
---@return boolean
function M.is_closed_directory(line)
    return M.get_icon(line) == config.icons.dir_closed
end

---Get the "visible" column width of `line`
---Since the path of the element is concealed, this will sum up:
---- indentation
---- icon
---- element name
---
---IMPORTANT: This function will not check the `conceallevel`
---@param line string The line to operate on
---@return number
function M.get_visible_width(line)
    local indentation, icon, _, _, name = line:match(line_pattern)
    return #indentation + #icon + 1 + #name -- one space between icon and element
end

-- ###############################################
-- ### general utility
-- ###############################################

---Simple wrapper around `vim.api.nvim_echo` to simplify its usage
---@param msg string Message which should be displayed
---@param highlight string (Optional) Highlight group to use
function M.echo(msg, highlight)
    highlight = highlight or 'None'
    api.nvim_echo({{ msg, highlight }}, false, {})
end

---Check if the given `buffer` is a valid DREX buffer
---If not this function will throw an error (on level 2)
---@param buffer number Buffer handle, or 0 for current buffer
function M.check_if_drex_buffer(buffer)
    if api.nvim_buf_get_option(buffer, 'filetype') ~= 'drex' then
        error('The given buffer is not a DREX buffer!', 2)
    end
end

---Expand the given path properly so it can be used within DREX
---Use `expand` to deal with special modifiers and `fnamemodify` to make the path absolute
---@param path string The path string which should be expanded
---@return string
function M.expand_path(path)
    return vim.fn.fnamemodify(vim.fn.expand(path), ':p')
end

---Get the root path of the given DREX `buffer`
---@param buffer number (Optional) Buffer handle, or 0 for current buffer (defaults to the current buffer)
---@return string
function M.get_root_path(buffer)
    buffer = buffer or api.nvim_get_current_buf()
    local buf_name = api.nvim_buf_get_name(buffer)
    return buf_name:match("^drex://(.*)$")
end

---Set the given `icon` for the specific `row`
---@param icon string The icon which should be set
---@param row number (Optional) 1-based index of the target row (defaults to the current row of the current window)
---@param buffer number (Optional) Buffer handle, or 0 for current buffer (defaults to the current buffer)
function M.set_icon(icon, row, buffer)
    row = row or api.nvim_win_get_cursor(0)[1]
    buffer = buffer or api.nvim_get_current_buf()

    local line = api.nvim_buf_get_lines(buffer, row - 1, row, false)[1]
    local indentation, old_icon = line:match(line_pattern)

    api.nvim_buf_set_text(buffer, row - 1, 0, row - 1, #indentation + #old_icon, { indentation .. icon })
end

-- ###############################################
-- ### LUV utility
-- ###############################################

---Use libuv to check if `path` points to a valid directory
---@param path string
---@return boolean
function M.is_valid_directory(path)
    local stats = vim.loop.fs_stat(path)
    return stats and stats.type == 'directory'
end

return M
