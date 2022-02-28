local M = {}

local utils = require('drex.utils')

function M.init()
    vim.cmd('autocmd VimEnter * lua require("drex.netrw").suppress()')
    vim.cmd('autocmd BufEnter * ++nested lua require("drex.netrw").hijack()')
end

function M.suppress()
    if vim.fn.exists('#FileExplorer') ~= 0 then
        vim.cmd('autocmd! FileExplorer *')
    end
end

---Check if the current buffer points to a directory
---If so replace it with a corresponding DREX buffer instead
function M.hijack()
    local path = vim.fn.expand('%:p')
    if not utils.is_valid_directory(path) then
        return
    end

    local buf = vim.api.nvim_get_current_buf()
    -- save the alternate file manually and restore it after the hijack
    -- we can not use `keepalt` as there are other commands called when opening a DREX buffer
    local alt_file = vim.fn.expand('#')

    vim.cmd('Drex ' .. utils.expand_path("%"))
    vim.api.nvim_buf_delete(buf, { force = true })

    -- only set alternate file if the buffer exists (prevent E94)
    if vim.fn.bufnr(alt_file) ~= -1 then
        vim.fn.setreg('#', alt_file)
    end
end

return M
