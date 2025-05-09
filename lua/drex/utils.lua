local M = {}

local api = vim.api
local luv = vim.loop
local config = require('drex.config')

-- ###############################################
-- ### string utility
-- ###############################################

---Escape `str` for the usage in a VIM regex
---@param str string String to escape
---@return string
function M.vim_escape(str)
    return vim.fn.escape(str, '^$.*~?/\\[]')
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

---Extract the indentation from a `line`
---The indentation are all spaces BEFORE the icon
---
---Examples:
---<pre>
---| Input                          | Output |
---|--------------------------------|--------|
---| " + /home/user"                | " "    |
---| "   · /home/user/example.json" | "   "  |
---</pre>
---@param line string The line string to operate on
---@return string
function M.get_indentation(line)
    local indentation = line:match(line_pattern)
    return indentation
end

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

---Checks the configured directory icons to see if the element on `line` is a directory
---@param line string The line to operate on
---@return boolean
function M.is_directory(line)
    local icon = M.get_icon(line)
    return icon == config.options.icons.dir_open or icon == config.options.icons.dir_closed
end

---Checks the configured directory icons to see if the element on `line` is an open directory
---@param line string The line to operate on
---@return boolean
function M.is_open_directory(line)
    return M.get_icon(line) == config.options.icons.dir_open
end

---Checks the configured directory icons to see of the element on `line` is a closed directory
---@param line string The line to operate on
---@return boolean
function M.is_closed_directory(line)
    return M.get_icon(line) == config.options.icons.dir_closed
end

---Set the given `icon` for the specific `row`
---@param icon string The icon which should be set
---@param row number? (Optional) 1-based index of the target row (defaults to the current row of the current window)
---@param buffer number? (Optional) Buffer handle, or 0 for current buffer (defaults to the current buffer)
function M.set_icon(icon, row, buffer)
    row = row or api.nvim_win_get_cursor(0)[1]
    buffer = buffer or api.nvim_get_current_buf()

    local line = api.nvim_buf_get_lines(buffer, row - 1, row, false)[1]
    local indentation, old_icon = line:match(line_pattern)

    api.nvim_buf_set_text(buffer, row - 1, 0, row - 1, #indentation + #old_icon, { indentation .. icon })
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
    return #indentation + api.nvim_strwidth(icon) + 1 + api.nvim_strwidth(name) -- one space between icon and element
end

-- ###############################################
-- ### drex specific utility
-- ###############################################

---Return if the given `buffer` is a DREX buffer
---@param buffer number Buffer handle, or 0 for current buffer
---@return boolean
function M.is_drex_buffer(buffer)
    return vim.api.nvim_buf_get_option(buffer, 'filetype') == 'drex'
end

---Check if the given `buffer` is a DREX buffer
---If not this function will throw an error (on level 2)
---@param buffer number Buffer handle, or 0 for current buffer
function M.check_if_drex_buffer(buffer)
    if not M.is_drex_buffer(buffer) then
        error('The given buffer is not a DREX buffer!', 2)
    end
end

---Get the root path of the given DREX `buffer`
---@param buffer number? (Optional) Buffer handle, or 0 for current buffer (defaults to the current buffer)
---@return string
function M.get_root_path(buffer)
    buffer = buffer or api.nvim_get_current_buf()
    local buf_name = api.nvim_buf_get_name(buffer)
    return buf_name:match('^drex://(.*)$')
end

---Reload the syntax option in all DREX buffers
function M.reload_drex_syntax()
    for _, buf in ipairs(api.nvim_list_bufs()) do
        if M.is_drex_buffer(buf) then
            api.nvim_buf_call(buf, function()
                vim.cmd('doautocmd Syntax')
            end)
        end
    end
end

-- ###############################################
-- ### window utility
-- ###############################################

---Simple utility to create a basic floating window with some "sane" default settings
---The window is automatically closed if the `buffer` is changed or when leaving the window
---When that happens the optionally provided `on_leave` function is called with the floating window handle as an argument. This will happen during an autocommand so some functions might not be applicable
---@param buffer number Buffer handle to be shown in the floating window
---@param on_leave function? Function to call when leaving buffer or window. The window handle is passed as an argument to this function
---@return number floating_win The window handle of the created window
function M.floating_win(buffer, on_leave)
    local lines = api.nvim_buf_get_lines(buffer, 0, -1, false)

    local vim_width = vim.opt.columns:get()
    local vim_height = vim.opt.lines:get()

    -- calculate floating window dimensions
    -- - height: 80% of the Neovim window
    -- - width:
    --   - 60% of Neovim window (default)
    --   - or at least 80 columns
    --   - or as long as the longest element (if enough space)
    local win_height = math.floor(vim_height * 0.8)
    local win_width = math.floor(vim_width * 0.6)

    win_width = win_width < 80 and 80 or win_width
    local max_element_width = vim.fn.max(vim.tbl_map(function(line)
        return #line
    end, lines))
    if max_element_width > win_width then
        if max_element_width > vim_width - 10 then
            win_width = vim_width - 10
        else
            win_width = max_element_width
        end
    end

    local x = math.floor((vim_width - win_width) / 2)
    local y = math.floor((vim_height - win_height) / 2)

    local win = api.nvim_open_win(buffer, true, {
        relative = 'editor',
        width = win_width,
        height = win_height,
        col = x,
        row = y,
        style = 'minimal',
        border = 'rounded',
        noautocmd = false,
    })
    api.nvim_win_set_option(win, 'wrap', false)

    api.nvim_create_autocmd('WinLeave', {
        buffer = buffer,
        nested = true, -- trigger nested "BufUnload" event
        callback = function()
            api.nvim_win_close(win, true)
        end,
    })

    -- register optional `on_leave` function
    if on_leave then
        api.nvim_create_autocmd('BufUnload', {
            buffer = buffer,
            callback = function()
                on_leave(win)
            end,
        })
    end

    return win
end

-- ###############################################
-- ### miscellaneous utility
-- ###############################################

---Simple wrapper around `vim.api.nvim_echo` to simplify its usage
---@param msg string Message which should be displayed
---@param history boolean? (Optional) Should the message be logged in the history (defaults to `false`)
---@param highlight string? (Optional) Highlight group to use (defaults to 'None')
function M.echo(msg, history, highlight)
    highlight = highlight or 'None'
    api.nvim_echo({ { msg, highlight } }, history, {})
end

---Expand the given path properly so it can be used within DREX
---Use `expand` to deal with special modifiers and `fnamemodify` to make the path absolute
---@param path string The path string which should be expanded
---@return string
function M.expand_path(path)
    return vim.fn.fnamemodify(vim.fn.expand(path), ':p')
end

---Use libuv to check if `path` points to an existing directory
---@param path string
---@return boolean
function M.points_to_existing_directory(path)
    local stats = vim.loop.fs_stat(path)
    return stats ~= nil and stats.type == 'directory'
end

---Reset the undo history for `buffer`
---@param buffer number Buffer handle, or 0 for current buffer
function M.buf_clear_undo_history(buffer)
    local old_undolevels = vim.opt.undolevels:get()
    api.nvim_buf_set_option(buffer, 'undolevels', -1)

    api.nvim_buf_call(buffer, function()
        vim.cmd(api.nvim_replace_termcodes('normal a <BS><ESC>', true, true, true))
    end)

    api.nvim_buf_set_option(buffer, 'undolevels', old_undolevels)
end

---Retrieve the (1-based) start and end row of the current or last visual selection
---@return number start_row
---@return number end_row
function M.get_visual_selection()
    local startRow = vim.fn.getpos("'<")[2]
    local endRow = vim.fn.getpos("'>")[2]
    if startRow < endRow then
        return startRow, endRow
    else
        return endRow, startRow
    end
end

---Shorten the given `path` so that it fits `max_width`, while keeping the whole path consistent and as "readable" as possible
---This is done by shortening the path elements to three, two or one character but keeping the target directory name intact (never shorten the root element like "C:")
---If this approach still does not fulfill the `max_width` it also includes the target directory name into the shortening process
---
---<pre>
---| Path                      | Max Width | Output                 |
---| ---                       | ---       | ---                    |
---| /home/user/projects/nvim  | 20        | ~/projects/nvim        |
---| /some/path/to/some/folder | 10        | /s/p/t/s/f             |
---| /some/path/to/some/folder | 15        | /s/p/t/s/folder        |
---| /some/path/to/some/folder | 20        | /so/pa/to/so/folder    |
---| /some/path/to/some/folder | 23        | /som/pat/to/som/folder |
---</pre>
---
---This uses `vim.fn.pathshorten` internally
---
---@param path string The path that should be shortened
---@param max_width number The maximum number of characters for the result
---@return string
function M.shorten_path(path, max_width)
    local sep = require('drex.utils').path_separator
    path = vim.fn.fnamemodify(path, ':~')

    -- remove trailing path separator
    if #path > 1 and vim.endswith(path, sep) then
        path = path:sub(1, -2)
    end

    if #path > max_width then
        local segments = vim.split(path, sep)
        local root = segments[1] -- never shorten the root drive (e.g. 'C:')
        local target = segments[#segments]
        local directories = table.concat(segments, sep, 2, #segments - 1) .. sep

        local short
        -- save shortened strings so we don't have to recalculate them
        local cache = {}

        -- only shorten the directories of the path and see if that is enough to match max_width
        for i = 3, 1, -1 do
            cache[i] = vim.fn.pathshorten(directories, i)
            short = string.format('%s' .. sep .. '%s%s', root, cache[i], target)

            if #short <= max_width then
                return short
            end
        end

        -- try and shorten the target element as well to match max_width
        for i = 3, 1, -1 do
            short = string.format('%s' .. sep .. '%s%s', root, cache[i], target:sub(1, i))

            if #short <= max_width then
                return short
            end
        end

        return short
    end

    return path
end

---Execute the given `cmd` and check if its execution was successful (via the exit code)
---This function does not check nor return the output of the given `cmd`
---@param cmd string The command which should be executed
---@param args table? The arguments which are provided to the command (default {})
---@param timeout number? Maximum time (in ms) to wait before aborting (default 3000)
---@return boolean successful If the command execution was successful
---@return string? error_message An error message if something went wrong (`nil` otherwise)
function M.cmd(cmd, args, timeout)
    args = args or {}
    timeout = timeout or 3000

    local success = nil
    local error = nil

    local stdin = luv.new_pipe()
    local stdout = luv.new_pipe()
    local stderr = luv.new_pipe()
    assert(stdin)
    assert(stdout)
    assert(stderr)

    luv.spawn(cmd, {
        args = args,
        stdio = { stdin, stdout, stderr },
    }, function(exit_code)
        success = exit_code == 0
    end)

    luv.read_start(stdout, function(err)
        if err then
            success = false
        end
    end)

    luv.read_start(stderr, function(_, data)
        error = error or data -- only catch the first error returned
    end)

    local done = vim.wait(timeout, function()
        return success ~= nil
    end)

    if not done then
        success = false
        error = 'The command "' .. cmd .. '" timed out in ' .. timeout .. 'ms!'
        luv.shutdown(stdin, function() end)
    end

    return success, error
end

return M
