local M = {}

local api = vim.api
local drex = require('drex')
local utils = require('drex.utils')
local config = require('drex.config').config

local drawer_widths = {}  -- save win width per tabpage
local drawer_windows = {} -- save win id per tabpage

---Return the drawer window for the current tabpage (if currently visible)
---@return number
function M.get_drawer_window()
    local win = drawer_windows[api.nvim_get_current_tabpage()]
    if win and api.nvim_win_is_valid(win) then
        return win
    end
end

---Open the drawer and focus it
---If the drawer is already open, only focus it
function M.open()
    local win = M.get_drawer_window()
    if not win then
        vim.cmd('vs')
        vim.cmd('wincmd H')

        local tab = api.nvim_get_current_tabpage()
        win = api.nvim_get_current_win()
        drawer_windows[tab] = win

        -- set `winfixwidth` to prevent resizing on window deletion & balancing
        api.nvim_win_set_option(win, 'winfixwidth', true)
        -- resize drawer to saved width (for this tab) or default
        local width = drawer_widths[tab] or config.drawer.default_width
        M.set_width(width, false, true)

        drex.open_directory_buffer('.')
    else
        api.nvim_set_current_win(win)
    end
end

---Close the drawer window (if currently open)
function M.close()
    if M.get_drawer_window() then
        local tab = api.nvim_get_current_tabpage()
        api.nvim_win_close(drawer_windows[tab], false)
        drawer_windows[tab] = nil
    end
end

---Toggle the drawer window
function M.toggle()
    if M.get_drawer_window() then
        M.close()
    else
        M.open()
    end
end

---Set the width of the drawer window (for the current tabpage) and resize it (optional)
---@param width number The new width or delta value (see `delta`)
---@param delta boolean Should the passed `width` parameter be treated as an absolute value or a delta
---@param resize boolean Should the drawer be resized afterwards or just set the size for storage
function M.set_width(width, delta, resize)
    local tab = api.nvim_get_current_tabpage()
    if delta then
        drawer_widths[tab] = drawer_widths[tab] + width
    else
        drawer_widths[tab] = width
    end

    if resize and M.get_drawer_window() then
        api.nvim_win_set_width(M.get_drawer_window(), drawer_widths[tab])
    end
end

---Find the given `path` in the drawer window and set the cursor to the corresponding line
---Open a drawer window (at 'cwd') if none is currently open
---This throws an error if the given `path` is not a sub path of the drawer's root path
---@param path string The element to find
---@param focus_drawer_window boolean Should the drawer window be focused after the element has been found
---@param resize_drawer_window boolean Should the drawer window be resized to fit the element (if there is not enough space already)
function M.find_element(path, focus_drawer_window, resize_drawer_window)
    path = utils.expand_path(path)

    local old_win = api.nvim_get_current_win()
    local drawer_window = M.get_drawer_window()
    if not drawer_window then
        M.open()
        drawer_window = M.get_drawer_window()
    end

    drex.focus_element(drawer_window, path)

    if resize_drawer_window then
        api.nvim_win_call(drawer_window, function()
            local element_width = utils.get_visible_width(api.nvim_get_current_line()) + 3 -- two for indentation and one as a small padding
            local drawer_width = api.nvim_win_get_width(drawer_window)
            if element_width > drawer_width then
                M.set_width(element_width, false, true)
            end
        end)
    end

    if focus_drawer_window then
        M.open()
    else
        api.nvim_set_current_win(old_win)
    end
end

return M
