local M = {}

local default_config = {
    icons = {
        dir_open = "",
        dir_closed = "",
        file_default = "🗎",
    },
    drawer = {
        default_width = 30,
        window_picker = {
            enabled = true,
            labels = 'abcdefghijklmnopqrstuvwxyz',
        },
    },
    disable_default_keybindings = false,
    keybindings = {
        ['n'] = {
            -- always use visual mode linewise for better visibility
            ['v'] = 'V',
            -- open/close directories
            ['l'] = '<cmd>lua require("drex").expand_element()<CR>',
            ['h'] = '<cmd>lua require("drex").collapse_directory()<CR>',
            ['<right>'] = '<cmd>lua require("drex").expand_element()<CR>',
            ['<left>']  = '<cmd>lua require("drex").collapse_directory()<CR>',
            ['<2-LeftMouse>'] = '<LeftMouse><cmd>lua require("drex").expand_element()<CR>',
            ['<RightMouse>']  = '<LeftMouse><cmd>lua require("drex").collapse_directory()<CR>',
            -- open files in separate windows/tabs
            ['<C-v>'] = '<cmd>lua require("drex").open_file("vs")<CR>',
            ['<C-x>'] = '<cmd>lua require("drex").open_file("sp")<CR>',
            ['<C-t>'] = '<cmd>lua require("drex").open_file("tabnew", true)<CR>',
            -- switch root directory
            ['<C-l>'] = '<cmd>lua require("drex").open_directory()<CR>',
            ['<C-h>'] = '<cmd>lua require("drex").open_parent_directory()<CR>',
            -- manual reload
            ['<F5>'] = '<cmd>lua require("drex").reload_directory()<CR>',
            -- jump around elements
            ['gj'] = '<cmd>lua require("drex.jump").jump_to_next_sibling()<CR>',
            ['gk'] = '<cmd>lua require("drex.jump").jump_to_prev_sibling()<CR>',
            ['gh'] = '<cmd>lua require("drex.jump").jump_to_parent()<CR>',
            -- file actions
            ['s'] = '<cmd>lua require("drex.actions").stats()<CR>',
            ['a'] = '<cmd>lua require("drex.actions").create()<CR>',
            ['d'] = '<cmd>lua require("drex.actions").delete("line")<CR>',
            ['D'] = '<cmd>lua require("drex.actions").delete("clipboard")<CR>',
            ['p'] = '<cmd>lua require("drex.actions").copy_and_paste()<CR>',
            ['P'] = '<cmd>lua require("drex.actions").cut_and_move()<CR>',
            ['r'] = '<cmd>lua require("drex.actions").rename()<CR>',
            ['R'] = '<cmd>lua require("drex.actions").multi_rename("clipboard")<CR>',
            -- add/remove elements from clipboard
            ['M'] = '<cmd>DrexMark<CR>',
            ['u'] = '<cmd>DrexUnmark<CR>',
            ['m'] = '<cmd>DrexToggle<CR>',
            ['cc'] = '<cmd>lua require("drex.actions").clear_clipboard()<CR>',
            ['cs'] = '<cmd>lua require("drex.actions").print_clipboard()<CR>',
            -- string copy utilities
            ['y'] = '<cmd>lua require("drex.actions").copy_element_name()<CR>',
            ['Y'] = '<cmd>lua require("drex.actions").copy_element_relative_path()<CR>',
            ['<C-y>'] = '<cmd>lua require("drex.actions").copy_element_absolute_path()<CR>',
        },
        ['v'] = {
            -- file actions
            ['d'] = ':lua require("drex.actions").delete("visual")<CR>',
            ['r'] = ':lua require("drex.actions").multi_rename("visual")<CR>',
            -- add/remove elements from clipboard
            ['M'] = ':DrexMark<CR>',
            ['u'] = ':DrexUnmark<CR>',
            ['m'] = ':DrexToggle<CR>',
            -- string copy utilities
            ['y'] = ':lua require("drex.actions").copy_element_name(true)<CR>',
            ['Y'] = ':lua require("drex.actions").copy_element_relative_path(true)<CR>',
            ['<C-y>'] = ':lua require("drex.actions").copy_element_absolute_path(true)<CR>',
        }
    },
    on_enter = nil,
    on_leave = nil,
}

---Helper function to check for valid directory icons
---This is important as these icons are used by utility functions to extract and set several options
---@param name string Name used for error message
---@param value string Value which should be checked
---@return boolean invalid `true` if there is a problem with the given `value`, `false` otherwise
local function is_invalid_dir_icon(name, value)
    if not value or #value == 0 or value:find('[ /\\]') then
        vim.api.nvim_err_writeln("Invalid icon value for '" .. name .. "': '" .. value .. "'! Icon has to be set, can not be blank and must not contain ' ', '/' or '\' characters!")
        return true
    end
    return false
end

---Helper function to check for supported `window_picker` labels
---@param labels table List of labels to validate
---@return boolean
local function validate_window_picker_labels(labels)
    local errors = {}
    local supported_labels = 'abcdefghijklmnopqrstuvwxyz'
    for c in labels:gmatch('.') do
        if not supported_labels:find(c) then
            table.insert(errors, c)
        end
    end

    if #errors > 0 then
        vim.api.nvim_err_writeln('Found invalid characters for `drawer.window_picker.labels`: ' .. table.concat(errors, '') .. ' fall back to default!')
        return false
    end

    return true
end

---Private table to store custom user functions used in keybindings
---Only intended for internal usage within the DREX plugin
M._fn = {}

M.config = default_config

---Configure the global DREX settings
---
---Overwrite default option values:
---<pre>
---{
---    icons = {
---        dir_open = "+",
---        dir_closed = "-"
---    }
---}
---</pre>
---
---Add additional or overwrite existing default DREX keybindings:
---<pre>
---{
---    -- default keybindings options are { noremap = true, silent = true, nowait = true }
---    keybindings = {
---        ['n'] = {
---            ['R'] = '<cmd>lua require"drex.actions".rename()<CR>',
---            ['d'] = function() require('drex.actions').delete() end,
---        }
---    }
---}
---</pre>
---
---Setting a keybinding to `false` removes it:
---<pre>
---{
---    keybindings = {
---        ['n'] = {
---            ['d'] = false
---        }
---    }
---}
---</pre>
---@param user_config table User specific configuration.
function M.configure(user_config)
    M.config = vim.tbl_deep_extend('force', default_config, user_config)

    -- overwrite ALL default keybindings if requested
    if M.config.disable_default_keybindings then
        M.config.keybindings = user_config.keybindings
    end

    -- check for valid directory icons
    if is_invalid_dir_icon('dir_open', M.config.icons.dir_open) then
        M.config.icons.dir_open = default_config.icons.dir_open
    end
    if is_invalid_dir_icon('dir_closed', M.config.icons.dir_closed) then
        M.config.icons.dir_closed = default_config.icons.dir_closed
    end

    -- check for valid window_picker labels
    if not validate_window_picker_labels(M.config.drawer.window_picker.labels) then
        M.config.drawer.window_picker.labels = default_config.drawer.window_picker.labels
    end

    -- reset mapped functions
    M._fn = {}
    for mode, bindings in pairs(M.config.keybindings) do
        for lhs, rhs in pairs(bindings) do
            if type(rhs) == 'function' then
                if not M._fn[mode] then
                    M._fn[mode] = {}
                end

                M._fn[mode][lhs] = rhs
            end
        end
    end
end

---Set all default keybindings for the given DREX buffer
---Called automatically by `ftplugin/drex.lua`
---Only intended for internal usage within the DREX plugin
---@param buffer number Buffer ID
function M.set_default_keybindings(buffer)
    local opts = { noremap = true, silent = true, nowait = true }

    for mode, bindings in pairs(M.config.keybindings) do
        for lhs, rhs in pairs(bindings) do
            -- check if `rhs` is truthy, users can set rhs to `false` to disable certain default bindings
            if rhs then
                if type(rhs) == 'function' then
                    -- call custom function from the `M._fn` table
                    rhs = string.format(":lua require('drex.config')._fn['%s']['%s']()<CR>", mode, lhs)
                end

                vim.api.nvim_buf_set_keymap(buffer, mode, lhs, rhs, opts)
            end
        end
    end

end

return M
