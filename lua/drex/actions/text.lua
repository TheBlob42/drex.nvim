local M = {}

local api = vim.api
local utils = require('drex.utils')

---Helper function to copy element string to the clipboard
---@param selection boolean If `true` use the last selection, if `false` only operate on the current line
---@param extract_fn function Function that should be used to extract the desired string value to copy
local function copy_element_strings(selection, extract_fn)
    local lines = {}
    if selection then
        local startRow, endRow = utils.get_visual_selection()
        for row = startRow, endRow, 1 do
            table.insert(lines, extract_fn(vim.fn.getline(row)))
        end
        vim.notify(
            'Copied ' .. (endRow - startRow + 1) .. ' values to text clipboard',
            vim.log.levels.INFO,
            { title = 'DREX' }
        )
    else
        local line_value = extract_fn(api.nvim_get_current_line())
        table.insert(lines, line_value)
        vim.notify("Copied '" .. line_value .. "' to text clipboard", vim.log.levels.INFO, { title = 'DREX' })
    end

    local value = table.concat(lines, '\n')

    -- use "charwise" for single lines
    -- use "linewise" for visual selections
    local mode = selection and 'l' or 'c'

    vim.fn.setreg('"', value, mode)
    vim.fn.setreg('*', value, mode)
    vim.fn.setreg('+', value, mode)
end

---Copy the element's name
---@param selection boolean? Indicator if called from visual mode (if so use last selection)
function M.copy_name(selection)
    utils.check_if_drex_buffer(0)
    copy_element_strings(selection, utils.get_name)
end

---Copy the element's path relative to the current root path
---@param selection boolean? Indicator if called from visual mode (if so use last selection)
function M.copy_relative_path(selection)
    utils.check_if_drex_buffer(0)
    local root_path = utils.get_root_path(0)
    copy_element_strings(selection, function(str)
        local name = utils.get_name(str)
        local path = utils.get_path(str)
        local rel_path = path:gsub(vim.pesc(root_path), '')
        return rel_path .. name
    end)
end

---Copy the absolute element's path
---@param selection boolean? Indicator if called from visual mode (if so use last selection)
function M.copy_absolute_path(selection)
    utils.check_if_drex_buffer(0)
    copy_element_strings(selection, utils.get_element)
end

return M
