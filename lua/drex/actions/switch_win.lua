-- This file only contains the `switch_window` function which shows a label per window and switches to it depending on user input
-- Due to all the character labels this file is quite long, so instead of blowing up another utils file we have outsourced it into its own file
-- Also you can easily extract this file to use it in your own config or plugin if you're in need of a similar functionality (probably with slight adaptions)

local M = {}

local api = vim.api
local config = require('drex.config')

---Make the letters more visible by setting the used highlight to "reverse"
local function set_hl()
    vim.api.nvim_set_hl(0, 'SwitchWindowReverse', { reverse = true })
end

set_hl()

vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('SwitchWindow', {}),
    pattern = '*',
    callback = set_hl,
})

local letters = {
    ['a'] = {
        ' ### ',
        '#   #',
        '#####',
        '#   #',
        '#   #',
    },
    ['b'] = {
        '#### ',
        '#   #',
        '#### ',
        '#   #',
        '#### ',
    },
    ['c'] = {
        ' ####',
        '#    ',
        '#    ',
        '#    ',
        ' ####',
    },
    ['d'] = {
        '#### ',
        '#   #',
        '#   #',
        '#   #',
        '#### ',
    },
    ['e'] = {
        '#####',
        '#    ',
        '#### ',
        '#    ',
        '#####',
    },
    ['f'] = {
        '#####',
        '#    ',
        '#### ',
        '#    ',
        '#    ',
    },
    ['g'] = {
        ' ####',
        '#    ',
        '# ###',
        '#   #',
        '#### ',
    },
    ['h'] = {
        '#   #',
        '#   #',
        '#####',
        '#   #',
        '#   #',
    },
    ['i'] = {
        ' ### ',
        '  #  ',
        '  #  ',
        '  #  ',
        ' ### ',
    },
    ['j'] = {
        '  ###',
        '   # ',
        '   # ',
        '#  # ',
        ' ##  ',
    },
    ['k'] = {
        '#   #',
        '#  # ',
        '###  ',
        '#  # ',
        '#   #',
    },
    ['l'] = {
        '#    ',
        '#    ',
        '#    ',
        '#    ',
        '#####',
    },
    ['m'] = {
        '#   #',
        '## ##',
        '# # #',
        '#   #',
        '#   #',
    },
    ['n'] = {
        '#   #',
        '##  #',
        '# # #',
        '#  ##',
        '#   #',
    },
    ['o'] = {
        ' ### ',
        '#   #',
        '#   #',
        '#   #',
        ' ### ',
    },
    ['p'] = {
        '#### ',
        '#   #',
        '#### ',
        '#    ',
        '#    ',
    },
    ['q'] = {
        ' ### ',
        '#   #',
        '#   #',
        '#  # ',
        ' ## #',
    },
    ['r'] = {
        '#### ',
        '#   #',
        '#### ',
        '#  # ',
        '#   #',
    },
    ['s'] = {
        '#####',
        '#    ',
        '#####',
        '    #',
        '#####',
    },
    ['t'] = {
        '#####',
        '  #  ',
        '  #  ',
        '  #  ',
        '  #  ',
    },
    ['u'] = {
        '#   #',
        '#   #',
        '#   #',
        '#   #',
        ' ### ',
    },
    ['v'] = {
        '#   #',
        '#   #',
        '#   #',
        ' # # ',
        '  #  ',
    },
    ['w'] = {
        '#   #',
        '#   #',
        '# # #',
        '## ##',
        '#   #',
    },
    ['x'] = {
        '#   #',
        ' # # ',
        '  #  ',
        ' # # ',
        '#   #',
    },
    ['y'] = {
        '#   #',
        ' # # ',
        '  #  ',
        '  #  ',
        '  #  ',
    },
    ['z'] = {
        '#####',
        '   # ',
        '  #  ',
        ' #   ',
        '#####',
    },
}

---Switch to another window than the current (ignore floating windows)
---If there is just one other window, switch directly to it
---If there are multiple other windows, show a character label for every other window and switch to window chosen by label
---Return `true` if the window was switched successfully (or if there was no other window)
---Return `false` if the user cancels the switch by choosing an invalid window label
---@return boolean
function M.switch_window()
    local current_window = api.nvim_get_current_win()
    local target_windows = vim.tbl_filter(function(win)
        if win == current_window then
            return false
        end

        -- ignore floating windows
        if vim.api.nvim_win_get_config(win).relative ~= '' then
            return false
        end

        return true
    end, api.nvim_tabpage_list_wins(0))

    if #target_windows == 0 then
        return true
    end

    if #target_windows == 1 then
        api.nvim_set_current_win(target_windows[1])
        return true
    end

    local targets = {}
    local label_windows = {}

    for index, win in ipairs(target_windows) do
        local label = config.options.drawer.window_picker.labels:sub(index, index)
        local label_buffer = api.nvim_create_buf(false, true)
        api.nvim_buf_set_text(label_buffer, 0, 0, 0, 0, letters[label])

        local label_window = api.nvim_open_win(label_buffer, false, {
            relative = 'win',
            win = win,
            anchor = 'NE',
            width = 5,
            height = 5,
            row = 0,
            col = api.nvim_win_get_width(win),
            focusable = false,
            style = 'minimal',
            border = 'rounded',
            noautocmd = true,
        })
        api.nvim_win_call(label_window, function()
            vim.fn.matchadd('SwitchWindowReverse', '#')
        end)
        table.insert(label_windows, label_window)

        targets[label] = win
    end

    vim.cmd('normal :<esc>') -- clear command line
    vim.cmd('redraw') -- make overlay windows instantly visible

    local input = vim.fn.nr2char(vim.fn.getchar())
    local target_window = targets[input]
    if target_window then
        api.nvim_set_current_win(target_window)
    end

    for _, win in ipairs(label_windows) do
        api.nvim_win_close(win, true)
    end

    return target_window and true
end

return M
