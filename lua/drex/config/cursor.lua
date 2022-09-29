local utils = require('drex.utils')

local saved_guicursor = vim.opt.guicursor:get()
local saved_cursorlineopt = vim.opt.cursorlineopt:get()

local hide_cursor_group = vim.api.nvim_create_augroup('DrexHideCursor', {})

---Create the "transparent" cursor highlight
local function set_cursor_hl()
    vim.api.nvim_set_hl(0, 'DrexTransparentCursor', {
        reverse = true, -- need to set some "gui" option or 'blend' will not work (at least in gnome-terminal)
        blend = 100,
    })
end

set_cursor_hl()

vim.api.nvim_create_autocmd('ColorScheme', {
    desc = 'Recreate the "transparent" DREX cursor highlight',
    pattern = '*',
    callback = set_cursor_hl,
})

---Hide the cursor by setting `guicursor` to our custom highlighting
local function hide_cursor()
    -- instantly hide the cursor to prevent flickering
    vim.opt.guicursor:append('a:DrexTransparentCursor/lCursor')
    vim.opt.cursorlineopt = { 'both' } -- the default value

    -- check if the cursor was hidden erroneously (if so restore it)
    vim.schedule(function()
        if not utils.is_drex_buffer(0) then
            vim.opt.guicursor = saved_guicursor
            vim.opt.cursorlineopt = saved_cursorlineopt
        end
    end)
end

---Restore the cursor by setting `guicursor` back to its initial value
local function restore_cursor()
    -- we schedule the call to check the "active" buffer (the one focused by the user)
    -- this should prevent false triggers by other (floating) windows
    -- also check if inside the cmdline to correctly restore the cursor there
    vim.schedule(function()
        if not utils.is_drex_buffer(0) or vim.fn.getcmdpos() > 0 then
            vim.opt.guicursor = saved_guicursor
            vim.opt.cursorlineopt = saved_cursorlineopt
        end
    end)
end

---Setup the autocommands for hiding the cursor within the current buffer and trigger them once
local function init()
    vim.api.nvim_create_autocmd({ 'BufEnter', 'CmdlineLeave', 'CmdwinLeave' }, {
        group = hide_cursor_group,
        buffer = 0,
        callback = hide_cursor,
    })

    vim.api.nvim_create_autocmd({ 'BufLeave', 'CmdlineEnter', 'CmdwinEnter' }, {
        group = hide_cursor_group,
        buffer = 0,
        callback = restore_cursor,
    })

    hide_cursor()
end

return { init = init }
