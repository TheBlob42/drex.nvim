require('drex.config').set_default_keybindings(0)

-- make sure that the cursor always stays in column 0 instead of jumping around on certain commands
vim.api.nvim_exec([[
    augroup DrexCursor
        autocmd! * <buffer>
        autocmd CursorMoved <buffer> normal! 0
    augroup END
]], false)
