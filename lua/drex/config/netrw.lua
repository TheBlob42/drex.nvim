local utils = require('drex.utils')
local initialized = false

---Check if the current buffer points to an existing directory
---If so replace it with a corresponding DREX buffer instead
local function hijack()
    local path = vim.fn.expand('%:p')
    if not utils.points_to_existing_directory(path) then
        return
    end

    local buf = vim.api.nvim_get_current_buf()
    -- save the alternate file manually and restore it after the hijack
    -- we can not use `keepalt` as there are other commands called when opening a DREX buffer
    local alt_file = vim.fn.expand('#')

    vim.cmd('Drex ' .. utils.expand_path('%'))
    vim.api.nvim_buf_delete(buf, { force = true })

    -- only set alternate file if the buffer exists (prevent E94)
    if vim.fn.bufnr(alt_file) ~= -1 then
        vim.fn.setreg('#', alt_file)
    end
end

local function init()
    if not initialized then
        initialized = true

        vim.api.nvim_create_autocmd('VimEnter', {
            pattern = '*',
            callback = function()
                if vim.fn.exists('#FileExplorer') ~= 0 then
                    vim.api.nvim_del_augroup_by_name('FileExplorer')
                end
            end,
        })

        vim.api.nvim_create_autocmd('BufEnter', {
            pattern = '*',
            nested = true,
            callback = hijack,
        })
    end
end

return { init = init }
