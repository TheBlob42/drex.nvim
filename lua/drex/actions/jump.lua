local M = {}

local api = vim.api
local utils = require('drex.utils')

---Jump to the parent element of the current line
function M.jump_to_parent()
    local buffer = api.nvim_get_current_buf()
    utils.check_if_drex_buffer(buffer)

    local path = utils.get_path(api.nvim_get_current_line())

    if path == utils.get_root_path(buffer) then
        vim.notify('Already at root path!', vim.log.levels.WARN, { title = 'DREX' })
        return
    end

    local parent_path = vim.fn.fnamemodify(path, ':h')

    local buflines = api.nvim_buf_get_lines(buffer, 0, -1, false)
    local row = api.nvim_win_get_cursor(0)[1]

    for i = (row - 1), 0, -1 do
        local line = buflines[i]
        if utils.get_element(line) == parent_path then
            row = i
            break
        end
    end

    api.nvim_win_set_cursor(0, { row, 0 })
end

---Jump to the next sibling element
function M.jump_to_next_sibling()
    local buffer = api.nvim_get_current_buf()
    utils.check_if_drex_buffer(buffer)

    local row = api.nvim_win_get_cursor(0)[1]
    local buflines = api.nvim_buf_get_lines(buffer, 0, -1, false)

    -- current line is the last line of the buffer
    if row == #buflines then
        return
    end

    local path = utils.get_path(api.nvim_get_current_line())

    for i = row + 1, #buflines, 1 do
        local line = buflines[i]
        if utils.get_path(line) == path then
            row = i
            break
        end
    end

    api.nvim_win_set_cursor(0, { row, 0 })
end

---Jump to the previous sibling element
function M.jump_to_prev_sibling()
    local buffer = api.nvim_get_current_buf()
    utils.check_if_drex_buffer(buffer)

    local row = api.nvim_win_get_cursor(0)[1]

    -- current line is the first line of the buffer
    if row == 1 then
        return
    end

    local path = utils.get_path(api.nvim_get_current_line())
    local buflines = api.nvim_buf_get_lines(buffer, 0, -1, false)

    for i = row - 1, 0, -1 do
        local line = buflines[i]
        if utils.get_path(line) == path then
            row = i
            break
        end
    end

    api.nvim_win_set_cursor(0, { row, 0 })
end

return M
