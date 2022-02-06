local M = {}

local saved_guicursor = vim.opt.guicursor:get()
local saved_cursorlineopt = vim.opt.cursorlineopt:get()

-- need to set some 'gui' option or 'blend' will not work (at least in gnome-terminal)
vim.cmd('highlight DrexTransparentCursor gui=reverse blend=100')

local function is_drex_buffer()
    return vim.api.nvim_buf_get_option(0, 'ft') == 'drex'
end

---Set up the autocommands for hiding the cursor and trigger them once
function M.init()
    vim.cmd [[
        augroup DrexHideCursor
            autocmd! * <buffer>
            autocmd BufEnter,CmdlineLeave,CmdwinLeave <buffer> lua require('drex.cursor').hide()
            autocmd BufLeave,CmdlineEnter,CmdwinEnter <buffer> lua require('drex.cursor').restore()
        augroup END
    ]]
    M.hide()
end

---Hide the cursor by setting `guicursor` to a custom highlighting
function M.hide()
    -- instantly hide the cursor to prevent flickering
    vim.opt.guicursor:append('a:DrexTransparentCursor/lCursor')
    vim.opt.cursorlineopt = { 'both' } -- the default value
    -- check if the cursor was hidden erroneously (if so restore it)
    vim.schedule(function()
        if not is_drex_buffer() then
            vim.opt.guicursor = saved_guicursor
            vim.opt.cursorlineopt = saved_cursorlineopt
        end
    end)
end

---Restore the cursor by setting `guicursor` back to its initial value
function M.restore()
    -- we schedule the call to check the "active" buffer (the one focused by the user)
    -- this should prevent false triggers by other (floating) windows
    -- also check if inside the cmdline to correctly restore the cursor there
    vim.schedule(function()
        if not is_drex_buffer() or vim.fn.getcmdpos() > 0 then
            vim.opt.guicursor = saved_guicursor
            vim.opt.cursorlineopt = saved_cursorlineopt
        end
    end)
end

return M
