local M = {}

local defaults = {
    icons = {
        file_default = "",
        -- icons which are not used by nvim-web-devicons
        dir_open = "",
        dir_closed = "",
        link = "",
        others = "",
    },
    colored_icons = true,
    hide_cursor = true,
    hijack_netrw = false,
    sorting = function(a, b)
        local aname, atype = a[1], a[2]
        local bname, btype = b[1], b[2]

        local aisdir = atype == 'directory'
        local bisdir = btype == 'directory'

        if aisdir ~= bisdir then
            return aisdir
        end

        return aname < bname
    end,
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
            ['cs'] = '<cmd>lua require("drex.actions").open_clipboard_window()<CR>',
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

---Helper function to check for valid icons
---Important as icons are used by utility functions for extracting and setting options
---@param name string Name of the icon element (for logging)
---@param value string Value to check
---@return boolean
local function validate_icon(name, value)
    if not value or #value == 0 or value:find('[ /\\]') then
        vim.notify(
            "Invalid icon value for '" .. name .. "': '" .. value .. "' icon has to be non-nil, can not be blank and must not contain ' ', '/' or '\\' characters!",
            vim.log.levels.ERROR,
            { title = 'DREX' })
        return false
    end
    return true
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
        vim.notify(
            'Found invalid characters for `drawer.window_picker.labels`: "' .. table.concat(errors, '') .. '" fall back to default!',
            vim.log.levels.ERROR,
            { title = 'DREX' }
        )
        return false
    end

    return true
end

---Helper function to check for a valid `sorting` function
---@param sorting any The sorting entry to validate. Should be `false` or a function
---@return boolean
local function validate_sorting(sorting)
    if sorting then
        if type(sorting) == 'function' then
            local test_data = {{ 'x', 'file' }, { 'y', 'link' }, { 'z', 'directory' }}
            local status_ok, error = pcall(table.sort, test_data, sorting)
            if not status_ok then
                vim.notify(
                    'The provided sorting function throws an error: "' .. error .. '" fall back to default!',
                    vim.log.levels.ERROR,
                    { title = 'DREX' })
                return false
            end
        else
            vim.notify(
                'The provided sorting is not a `function`, fall back to default!',
                vim.log.levels.ERROR,
                { title = 'DREX' })
            return false
        end
    end

    return true
end

M.options = defaults

---Configure the global DREX settings
---@param user_config table User specific configuration.
function M.configure(user_config)
    M.options = vim.tbl_deep_extend('force', defaults, user_config)

    -- overwrite ALL default keybindings if requested
    if M.options.disable_default_keybindings then
        M.options.keybindings = user_config.keybindings
    end

    -- check for valid icons
    if not validate_icon('file_default', M.options.icons.file_default) then
        M.options.icons.file_default = defaults.icons.file_default
    end
    if not validate_icon('dir_open', M.options.icons.dir_open) then
        M.options.icons.dir_open = defaults.icons.dir_open
    end
    if not validate_icon('dir_closed', M.options.icons.dir_closed) then
        M.options.icons.dir_closed = defaults.icons.dir_closed
    end
    if not validate_icon('link', M.options.icons.link) then
        M.options.icons.link = defaults.icons.link
    end
    if not validate_icon('others', M.options.icons.others) then
        M.options.icons.others = defaults.icons.others
    end

    -- check for valid window_picker labels
    if not validate_window_picker_labels(M.options.drawer.window_picker.labels) then
        M.options.drawer.window_picker.labels = defaults.drawer.window_picker.labels
    end

    -- check for a valid sort function
    if not validate_sorting(M.options.sorting) then
        M.options.sorting = defaults.sorting
    end
end

---Set all default keybindings for the given DREX buffer
---Called automatically by `ftplugin/drex.lua`
---Only intended for internal usage within the DREX plugin
---@param buffer number Buffer ID
function M.set_default_keybindings(buffer)
    local opts = { noremap = true, silent = true, nowait = true }

    for mode, bindings in pairs(M.options.keybindings) do
        for lhs, rhs in pairs(bindings) do
            -- check if `rhs` is truthy, users can set rhs to `false` to disable certain default bindings
            if rhs then
                if type(rhs) == 'function' then
                    rhs = string.format(
                        ":lua require('drex.config').options.keybindings['%s']['%s']()<CR>",
                        mode,
                        lhs:gsub('<', '<lt>') -- escape keycodes like '<CR>', '<Esc>', etc.
                    )
                end

                vim.api.nvim_buf_set_keymap(buffer, mode, lhs, rhs, opts)
            end
        end
    end

end

return M
