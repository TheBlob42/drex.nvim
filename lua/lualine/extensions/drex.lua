local M = {}

local short_path = function()
    local utils = require('drex.utils')
    local width = vim.api.nvim_win_get_width(0)
    local path = utils.get_root_path(0)

    -- 4 spaces + 2 separators + 1 buffer = 7
    return utils.shorten_path(path, width - 7)
end

local clipboard_entries = function()
    return vim.tbl_count(require('drex.clipboard').clipboard)
end

M.sections = {
    lualine_a = { short_path },
    lualine_z = { clipboard_entries },
}

M.filetypes = {
    'drex',
}

return M
