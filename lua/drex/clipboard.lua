local M = {}

local api = vim.api
local luv = vim.loop
local utils = require('drex.utils')

local clipboard_group = api.nvim_create_augroup('DrexClipboardBuffer', {})

M.clipboard = {}

---Clear the clipboard
function M.clear_clipboard()
    M.clipboard = {}
    utils.reload_drex_syntax()
end

---Return all elements currently contained in the DREX clipboard
---You can specify a sort order ('asc' or 'desc'), otherwise the elements might be returned in any order
---
---If you want to perform any actions on the contained elements you should set the `sort_order` to 'desc' so that more detailed paths occur first in the result list
---
---<pre>
---{
---  "/home/user/dir/file.txt",
---  "/home/user/dir",
---}
---</pre>
---
---This should be done so that all performed actions have a deterministic outcome
---In the above example `copy_and_paste` would first copy `file.txt` to the destination and then copy `dir` (including `file.txt` within it's content)
---
---<pre>
---destination/
---- file.txt
---- dir/
---  - file.txt
---  - ...
---</pre>
---
---Otherwise the `copy_and_paste` function would sometimes not be deterministic, depending on the order of the clipboard entries
---@param sort_order string? (Optional) If provided sort the clipboard entries accordingly ('asc' or 'desc')
---@return table
function M.get_clipboard_entries(sort_order)
    local clipboard_entries = vim.tbl_keys(M.clipboard)

    if sort_order == 'asc' then
        table.sort(clipboard_entries)
    elseif sort_order == 'desc' then
        table.sort(clipboard_entries, function(a, b) return a > b end)
    end

    return clipboard_entries
end

---Edit all DREX clipboard entries in a floating window
---Some important notes:
---- The clipboard is updated once you leave the buffer or close the window
---- Empty lines and comments (starting with '#') will be ignored
---- Invalid paths will also be ignored
function M.open_clipboard_window()
    local elements = M.get_clipboard_entries('asc')
    local buf_lines = {
        '# DREX CLIPBOARD',
        '',
        '# Confirm changes by leaving this buffer or closing the window and approve the',
        "# confirmation (only if changes exist). Empty lines, comments starting with '#'",
        '# and non-existing elements will be ignored and not added to the clipboard',
        '',
        unpack(elements)
    }

    local buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buffer, 0, -1, false, buf_lines)
    api.nvim_buf_set_option(buffer, 'buftype', 'nofile')
    api.nvim_buf_set_option(buffer, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(buffer, 'syntax', 'gitcommit')
    api.nvim_buf_set_name(buffer, 'DREX Clipboard')
    utils.buf_clear_undo_history(buffer)

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
    local max_element_width = vim.fn.max(vim.tbl_map(function(element) return #element end, elements))
    if max_element_width > win_width then
        if max_element_width > vim_width - 10 then
            win_width = vim_width - 10
        else
            win_width = max_element_width
        end
    end

    local x = math.floor((vim_width - win_width) / 2)
    local y = math.floor((vim_height - win_height) / 2)

    local clipboard_win = api.nvim_open_win(buffer, true, {
        relative = 'editor',
        width = win_width,
        height = win_height,
        col = x,
        row = y,
        style = 'minimal',
        border = 'rounded',
        noautocmd = false,
    })
    api.nvim_win_set_option(clipboard_win, 'wrap', false)

    local on_close = function()
        local buf_elements = {}

        for _, element in ipairs(api.nvim_buf_get_lines(buffer, 0, -1, false)) do
            if element ~= '' and not vim.startswith(element, '#') then
                if vim.endswith(element, utils.path_separator) then
                    -- remove trailing path separator for directories
                    element = element:sub(1, #element - 1)
                end

                if luv.fs_access(element, 'r') then
                    table.insert(buf_elements, element)
                end
            end
        end

        table.sort(buf_elements)

        if table.concat(elements) ~= table.concat(buf_elements) then
            vim.cmd('redraw')
            local apply_changes = vim.fn.confirm('Should your changes be applied?', '&Yes\n&No', 1) == 1

            if apply_changes then
                local tmp_clipboard = {}
                for _, element in ipairs(buf_elements) do
                    tmp_clipboard[element] = true
                end
                M.clipboard = tmp_clipboard

                utils.reload_drex_syntax()
            end
        end

        vim.schedule(function()
            if api.nvim_win_is_valid(clipboard_win) then
                api.nvim_win_close(clipboard_win, true)
            end
        end)
    end

    api.nvim_clear_autocmds {
        group = clipboard_group,
        buffer = buffer,
    }
    api.nvim_create_autocmd('WinLeave', {
        group = clipboard_group,
        buffer = buffer,
        callback = on_close,
    })
    api.nvim_create_autocmd('BufUnload', {
        group = clipboard_group,
        buffer = buffer,
        callback = on_close,
    })
end

---Mark the elements from `startRow` to `endRow` and add them to the DREX clipboard
---If not both parameters are provided use the current line as default
---@param startRow number
---@param endRow number
function M.mark(startRow, endRow)
    if not startRow or not endRow then
        startRow = api.nvim_win_get_cursor(0)[1]
        endRow = api.nvim_win_get_cursor(0)[1]
    end

    for row = startRow, endRow, 1 do
        local element = utils.get_element(vim.fn.getline(row))
        M.clipboard[element] = true
    end

    utils.reload_drex_syntax()
end

---Unmark the elements from `startRow` to `endRow` and remove them from the DREX clipboard
---If not both parameters are provided use the current line as default
---@param startRow number
---@param endRow number
function M.unmark(startRow, endRow)
    if not startRow or not endRow then
        startRow = api.nvim_win_get_cursor(0)[1]
        endRow = api.nvim_win_get_cursor(0)[1]
    end

    for row = startRow, endRow, 1 do
        local element = utils.get_element(vim.fn.getline(row))
        M.clipboard[element] = nil
    end

    utils.reload_drex_syntax()
end

---Toggle the elements from `startRow` to `endRow`
---- A marked row will be unmarked and removed from the DREX clipboard
---- An unmarked row will be marked and added to the DREX clipboard
---If not both parameters are provided use the current line as default
---@param startRow number
---@param endRow number
function M.toggle(startRow, endRow)
    if not startRow or not endRow then
        startRow = api.nvim_win_get_cursor(0)[1]
        endRow = api.nvim_win_get_cursor(0)[1]
    end

    for row = startRow, endRow, 1 do
        local element = utils.get_element(vim.fn.getline(row))
        M.clipboard[element] = not M.clipboard[element] or nil
    end

    utils.reload_drex_syntax()
end

return M
