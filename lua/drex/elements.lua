local M = {}

local api = vim.api
local luv = vim.loop

local fs = require('drex.fs')
local utils = require('drex.utils')
local config = require('drex.config')

---Expand the `path` within the given DREX `buffer` and return the (1-based) row of the target element
---This function will expand sub directories to get to the target element if needed
---
---An error is thrown under the following conditions:
---- The `path` is equal to the root path of the buffer
---- The `path` is not relative to the root path of `buffer`
---- The target element does not exist
---@param buffer number The target DREX buffer
---@param path string? Path of the target element (defaults to the current file)
---@return number? row The (1-based) row of the target element, `nil` when `path` could not be found
local function expand_path(buffer, path)
    path = utils.expand_path(path or '%')
    local root_path = utils.get_root_path(buffer)

    if path == root_path then
        error("The given path '" .. path .. "' is equal to the buffers root path!", 0)
    end

    if not vim.startswith(path, root_path) then
        error("Can not find '" .. path .. "'! Wrong root path ('" .. root_path .. "').", 0)
    end

    if not luv.fs_access(path, 'r') then
        error("'" .. path .. "' does not exist!", 0)
    end

    -- cut trailing path separator (e.g. '/') for directories
    if vim.endswith(path, utils.path_separator) then
        path = path:sub(1, -(#utils.path_separator + 1))
    end

    local row = 0
    while true do
        local line = api.nvim_buf_get_lines(buffer, row, row + 1, false)[1]

        if not line then
            return
        end

        if path == utils.get_element(line) then
            return row + 1
        end

        local element = utils.get_element(line)
        if vim.startswith(path, element .. utils.path_separator) then
            if utils.is_closed_directory(line) then
                M.expand_element(buffer, row + 1) -- one-based
            end
        end

        row = row + 1
    end
end

---Expand the element in `row` in the given DREX `buffer`
---If the element is a closed directory expand its subtree
---If the element is a file open it (see `open_file`)
---Otherwise don't do anything
---@param buffer number? (Optional) Buffer handle, or 0 for current buffer (defaults to the current buffer)
---@param row number? (Optional) 1-based index of the row to expand (defaults to the current row)
function M.expand_element(buffer, row)
    buffer = buffer or api.nvim_get_current_buf()
    if buffer == 0 then
        buffer = api.nvim_get_current_buf() -- get "actual" buffer id
    end

    utils.check_if_drex_buffer(buffer)

    local line
    if not row then
        -- by default use the current line of the current window
        line = api.nvim_get_current_line()
        row = api.nvim_win_get_cursor(0)[1]
    else
        line = api.nvim_buf_get_lines(buffer, row - 1, row, false)[1]
    end

    if not utils.is_directory(line) then
        M.open_file()
        return
    end

    if utils.is_closed_directory(line) then
        local path = utils.get_element(line) .. utils.path_separator

        local sub_dir_content = fs.scan_directory(path, utils.get_root_path(buffer))
        -- if something goes wrong while extracting the directory content --> abort
        if not sub_dir_content then
            return
        end

        api.nvim_buf_set_option(buffer, 'modifiable', true)
        vim.fn.appendbufline(buffer, row, sub_dir_content)
        utils.set_icon(config.options.icons.dir_open, row, buffer)
        api.nvim_buf_set_option(buffer, 'modifiable', false)

        fs.watch_directory(buffer, path)
    end
end

---Collapse the directory element in `row` in `buffer`
---If the element is an open directory collapse its subtree
---Otherwise collapse the parent directory of the given element
---@param buffer number? (Optional) Buffer handle, or 0 for current buffer (defaults to the current buffer)
---@param row number? (Optional) 1-based index of the row to collapse (defaults to the current row)
function M.collapse_directory(buffer, row)
    buffer = buffer or api.nvim_get_current_buf() -- defaults to current buffer

    utils.check_if_drex_buffer(buffer)

    local line
    if not row then
        -- by default use the line of the current window
        line = api.nvim_get_current_line()
        row = api.nvim_win_get_cursor(0)[1]
    else
        -- `nvim_buf_get_lines` uses a 0-based index
        line = api.nvim_buf_get_lines(buffer, row - 1, row, false)[1]
    end

    local start_row -- row of the directory to collapse
    local end_row -- last row of content for the collapsing directory

    -- slightly different behavior depending on the element in `row`
    -- --> open directory : collapse this directory element
    -- --> default        : collapse the parent directory of the current element
    local path
    if utils.is_open_directory(line) then
        start_row = row
        path = utils.get_element(line) .. utils.path_separator
    else
        path = utils.get_path(line)
    end

    -- don't collapse the root path of the DREX buffer
    if path == utils.get_root_path(buffer) then
        vim.notify('Can not collapse root path!', vim.log.levels.WARN, { title = 'DREX' })
        return
    end

    local buffer_lines = api.nvim_buf_get_lines(buffer, 0, -1, false)

    -- find the row containing the directory to collapse
    if not start_row then
        for r = row, 0, -1 do
            local tmpLine = buffer_lines[r]
            if vim.startswith(path, utils.get_element(tmpLine)) then
                start_row = r
                break
            end
        end
    end

    -- find the last "content row" of the directory to collapse
    for r = row + 1, #buffer_lines, 1 do
        local tmpLine = buffer_lines[r]
        if not vim.startswith(utils.get_path(tmpLine), path) then
            -- r is the first row not belonging to the collapsing directory
            -- therefore we save the previous row as 'end_row'
            end_row = r - 1
            break
        end
    end

    -- special case if the directory content is the last entry
    if not end_row then
        end_row = #buffer_lines
    end

    api.nvim_buf_set_option(buffer, 'modifiable', true)
    -- check that the directory is not empty (no contents)
    if start_row ~= end_row then
        api.nvim_buf_set_lines(buffer, start_row, end_row, false, {})
    end
    utils.set_icon(config.options.icons.dir_closed, start_row, buffer)
    api.nvim_win_set_cursor(0, { start_row, 0 })
    api.nvim_buf_set_option(buffer, 'modifiable', false)

    fs.unwatch_directory(buffer, path)
end

---Open the parent directory of the current root path in a new DREX buffer
function M.open_parent_directory()
    utils.check_if_drex_buffer(api.nvim_get_current_buf())

    local root_path = utils.get_root_path(0)
    -- double `fnamemodify` to ensure trailing path separator (except for root)
    local fnamemodify = vim.fn.fnamemodify
    local parent_path = fnamemodify(fnamemodify(root_path, ':h:h'), ':p')

    if root_path == parent_path then
        return vim.notify("'" .. root_path .. "' has no parent!", vim.log.levels.WARN, { title = 'DREX' })
    end

    require('drex').open_directory_buffer(parent_path)
    M.focus_element(0, root_path)
end

---Open the directory under the cursor in a new DREX buffer
---If the element under the cursor is not a directory use its path instead
function M.open_directory()
    utils.check_if_drex_buffer(api.nvim_get_current_buf())

    local path
    local line = api.nvim_get_current_line()
    if utils.is_directory(line) then
        path = utils.get_element(line) .. utils.path_separator
    else
        path = utils.get_path(line)
    end

    require('drex').open_directory_buffer(path)
end

---Open the file under the cursor
---@param pre string? VIM command to execute before opening the file (e.g. to split the window first)
---@param change_tab boolean? Indicator if your `pre` command is switching to another tabpage (skip the drawer special handling if so)
function M.open_file(pre, change_tab)
    local line = api.nvim_get_current_line()

    if utils.is_directory(line) then
        vim.notify('Current line is not a file!', vim.log.levels.ERROR, { title = 'DREX' })
        return
    end

    -- if used in drawer, switch to another window first
    local win = api.nvim_get_current_win()
    local is_drawer = win == require('drex.drawer').get_drawer_window()

    if is_drawer and not change_tab then
        if config.options.drawer.window_picker.enabled then
            if not require('drex.actions.switch_win').switch_window() then
                -- user has not chosen a valid window or aborted
                return
            end
        else
            vim.cmd('wincmd p')
            -- there are situations in which 'wincmd p' doesn't work
            -- see: https://github.com/vim/vim/issues/4537
            if api.nvim_get_current_win() == win then
                vim.cmd('wincmd l')
            end
        end

        -- in case the drawer window is the last window of the current tabpage
        if api.nvim_get_current_win() == win then
            vim.cmd('rightbelow vsplit')
            require('drex.drawer').set_width(0, true, true)
        end
    end

    if pre then
        vim.cmd(pre)
    end

    -- since we're leaving into a non-DREX buffer we have to reset this
    vim.w.coming_from_another_drex_buffer = nil

    -- as the drawer is opening the file in another window we have to ignore keepalt here
    if is_drawer or not config.options.keepalt then
        pcall(vim.cmd.e, utils.get_element(line))
    else
        -- use `pcall` in case of a VIM error (e.g. file is already opened in another VIM instance - E325)
        ---@diagnostic disable-next-line: param-type-mismatch
        pcall(vim.cmd, 'keepalt e ' .. utils.get_element(line))
    end
end

---Find the element represented by `path` and set the cursor in `win` to the corresponding line
---This function will expand sub-directories if needed to reach the target
---
---An error is thrown under the following conditions:
---- The window id `win` is invalid
---- The buffer in `win` is not a DREX buffer
---- The given `path` is not relative to the root path of the targeted DREX buffer
---@param win number The target window id (0 for current window)
---@param path string? (Optional) Path of the target element (defaults to the current file)
function M.focus_element(win, path)
    if win == 0 then
        -- get the "real" window id for the current window (instead of 0)
        -- `win_execute` does not work correctly with the value '0'
        win = vim.fn.win_getid()
    end

    if not api.nvim_win_is_valid(win) then
        utils.echo('Window ' .. win .. ' does not exist!', true, 'ErrorMsg')
        return
    end

    local buffer = api.nvim_win_get_buf(win)
    utils.check_if_drex_buffer(buffer)

    local row = expand_path(buffer, path)
    if row then
        local visible = vim.fn.line('w0') <= row and row <= vim.fn.line('w$')

        -- set the cursor to the target row and center the view
        api.nvim_win_set_cursor(win, { row, 0 })
        if not visible then
            vim.schedule(function()
                vim.fn.win_execute(win, 'normal! zz')
            end)
        end
    end
end

return M
