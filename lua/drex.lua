local M = {}

local api = vim.api
local buf_local_group = vim.api.nvim_create_augroup('DrexBufLocal', {})

local fs = require('drex.fs')
local utils = require('drex.utils')
local config = require('drex.config')

---Check if the given DREX `buffer` is empty and if so (re)load the corresponding directory content
---@param buffer number The DREX buffer to check
---@return boolean loaded `true` if the content was (re)loaded and inserted successfully, `false` otherwise
local function load_buffer_content(buffer)
    local buflines = api.nvim_buf_get_lines(buffer, 0, -1, false)

    if #buflines == 0 then
        utils.echo(
            'DREX buffer '
                .. buffer
                .. ' is either unloaded or in a "funky" state. This should not happen, so check if we can reproduce it and file an issue :-)',
            true,
            'WarningMsg'
        )
    end

    -- check if the buffer has any "content" (any lines with text)
    -- the buffer can be empty for three reasons:
    -- --> newly created drex buffer
    -- --> empty directory
    -- --> loading error (e.g. call ':e' in a drex buffer)
    if #buflines == 1 and buflines[1] == '' then
        local path = utils.get_root_path(buffer)
        local dir_content = fs.scan_directory(path)
        if dir_content and #dir_content > 0 then
            api.nvim_buf_set_option(buffer, 'modifiable', true)
            api.nvim_buf_set_lines(buffer, 0, -1, false, dir_content)
            api.nvim_buf_set_option(buffer, 'modifiable', false)
        end

        return true
    end

    return false
end

---Set sane local defaults when entering a DREX buffer
local function on_enter()
    vim.opt_local.wrap = false -- wrap and conceal don't play well together
    vim.opt_local.cursorline = true -- make the selected line better visible
    vim.opt_local.conceallevel = 3 -- hide full path completely
    vim.opt_local.concealcursor = 'nvc' -- don't reveal full path on cursor
    vim.opt_local.spell = false -- spell checking is usually just annoying
    vim.opt_local.signcolumn = 'no' -- hide the signcolumn

    if config.options.on_enter then
        config.options.on_enter()
    end

    vim.cmd('doautocmd Syntax') -- reload syntax
end

---Call custom logic when leaving a DREX buffer
local function on_leave()
    if config.options.on_leave then
        config.options.on_leave()
    end
end

---Open a DREX buffer pointing to a given directory `path`
---If a corresponding buffer already exists reuse it instead of creating a new one
---@param path string? (Optional) The path to a directory which should be opened (defaults to cwd)
function M.open_directory_buffer(path)
    path = utils.expand_path(path or '.')

    if not utils.points_to_existing_directory(path) then
        vim.notify(
            "The path '" .. path .. "' does not point to an existing directory!",
            vim.log.levels.ERROR,
            { title = 'DREX' }
        )
        return
    end

    local buffer_name = 'drex://' .. path
    local buffer = vim.fn.bufnr('^' .. buffer_name .. '$')
    -- if a corresponding DREX buffer does not exist yet create one
    if buffer == -1 then
        buffer = api.nvim_create_buf(true, true)
        api.nvim_buf_set_name(buffer, buffer_name)
        fs.watch_directory(buffer, path)
    end

    -- to make it work with `airblade/vim-rooter`
    api.nvim_buf_set_var(buffer, 'rootDir', path)
    -- (re)set some basic buffer options
    api.nvim_buf_set_option(buffer, 'buftype', 'nofile')
    api.nvim_buf_set_option(buffer, 'modifiable', false)
    api.nvim_buf_set_option(buffer, 'shiftwidth', 2)

    -- set the buffer to the current window in order to properly load it
    api.nvim_buf_set_option(buffer, 'filetype', 'drex')

    if config.options.keepalt and vim.w.coming_from_another_drex_buffer then
        vim.cmd('keepalt b ' .. buffer)
    else
        vim.w.coming_from_another_drex_buffer = 1
        api.nvim_set_current_buf(buffer)
    end

    -- set buffer content for new and "damaged" DREX buffers
    load_buffer_content(buffer)

    -- set "sane defaults" autocmds
    api.nvim_clear_autocmds({
        group = buf_local_group,
        buffer = buffer,
    })
    vim.api.nvim_create_autocmd('BufEnter', {
        group = buf_local_group,
        buffer = buffer,
        callback = on_enter,
    })
    vim.api.nvim_create_autocmd('BufLeave', {
        group = buf_local_group,
        buffer = buffer,
        callback = on_leave,
    })
    -- trigger it once to set defaults
    on_enter()
end

---Reloads the content of the directory given by `path` in the DREX `buffer`
---Expanded sub directories will be expanded again after the reload (if possible)
---@param buffer number? (Optional) Buffer handle, or 0 for current buffer (defaults to the current buffer)
---@param path string? (Optional) Path which should be reloaded (defaults to the root path of the current DREX buffer)
function M.reload_directory(buffer, path)
    buffer = buffer or api.nvim_get_current_buf()

    if buffer == 0 then
        buffer = api.nvim_get_current_buf() -- get "actual" buffer id
    end

    if not api.nvim_buf_is_loaded(buffer) then
        return
    end

    utils.check_if_drex_buffer(buffer)

    local root_path = utils.get_root_path(buffer)
    path = path or root_path

    if not utils.points_to_existing_directory(path) then
        utils.echo("The path '" .. path .. "' does not point to an existing directory!", true, 'ErrorMsg')
        return
    end

    local elements = require('drex.elements')
    -- check if the buffer content has been erased and reload if necessary
    if load_buffer_content(buffer) then
        -- if we had to reset the whole buffer content we can abort here
        -- but at least we should expand `path` (in case it's not the root path of current buffer)
        if path ~= root_path then
            local row = elements.expand_path(buffer, path)
            elements.expand_element(buffer, row)
        end
        return
    end

    local buffer_lines = api.nvim_buf_get_lines(buffer, 0, -1, false)
    local start_row -- the first row which belongs to the given path
    local end_row -- the last row which belongs to the given path
    local open_dirs = {} -- remember open directories (to afterwards re-open them again)

    if path == root_path then
        start_row = 0
    end

    for row, line in ipairs(buffer_lines) do
        if not start_row and (utils.get_element(line) .. utils.path_separator) == path then
            start_row = row
        elseif start_row then
            local line_path = utils.get_path(line)

            if not vim.startswith(line_path, path) then
                end_row = row - 1
                break
            end

            if utils.is_open_directory(line) then
                open_dirs[utils.get_element(line)] = true
            end
        end
    end

    -- path was not found in the given buffer
    if not start_row then
        return
    end

    -- either `path` is the root path of `buffer`
    -- or the last line of `buffer` belongs to the sub-directory's content
    if not end_row then
        end_row = #buffer_lines
    end

    -- save the cursor position for all windows which are currently displaying `buffer`
    local windows = {}
    for _, win in ipairs(api.nvim_list_wins()) do
        if api.nvim_win_get_buf(win) == buffer then
            windows[win] = api.nvim_win_get_cursor(win)
        end
    end

    local new_content = fs.scan_directory(path, utils.get_root_path(buffer))
    if new_content then
        api.nvim_buf_set_option(buffer, 'modifiable', true)
        api.nvim_buf_set_lines(buffer, start_row, end_row, false, new_content)
        api.nvim_buf_set_option(buffer, 'modifiable', false)
    else
        -- if the directory scan failed abort right here
        return
    end

    if #new_content == 0 then
        -- empty directory, we can take a shortcut here
        return
    end

    if start_row >= api.nvim_buf_line_count(buffer) then
        -- `path` got deleted completely
        -- `path` was the last element of `buffer`
        return
    end

    if vim.tbl_count(open_dirs) > 0 then
        -- reopen previously opened sub directories
        local progress = true
        while progress do
            local lines = api.nvim_buf_get_lines(buffer, start_row, -1, false)
            for row, line in ipairs(lines) do
                local element = utils.get_element(line)
                if open_dirs[element] and utils.is_directory(line) then
                    elements.expand_element(buffer, row + start_row)
                    start_row = start_row + row
                    break
                end

                -- outside of given path
                if not vim.startswith(element, path) then
                    progress = false
                    break
                end

                -- no more lines to check
                if row == #lines then
                    progress = false
                end
            end
        end
    end

    -- restore cursor positions for all windows that display `buffer`
    for win, pos in pairs(windows) do
        -- use `pcall` as the cursor position might be invalid (outside of the displayed buffer)
        local success = pcall(api.nvim_win_set_cursor, win, pos)
        if not success then
            api.nvim_win_call(win, function()
                vim.cmd('normal G')
            end)
        end
    end
end

return M
