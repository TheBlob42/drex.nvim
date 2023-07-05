local M = {}

local defaults = {
    icons = {
        file_default = '',
        -- icons which are not used by nvim-web-devicons
        dir_open = '',
        dir_closed = '',
        link = '',
        others = '',
    },
    colored_icons = true,
    hide_cursor = true,
    hijack_netrw = false,
    keepalt = false,
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
        side = 'left',
        default_width = 30,
        window_picker = {
            enabled = true,
            labels = 'abcdefghijklmnopqrstuvwxyz',
        },
    },
    actions = {
        files = {
            delete_cmd = nil,
        },
    },
    disable_default_keybindings = false,
    keybindings = {
        ['n'] = {
            -- always use visual mode linewise for better visibility
            ['v'] = 'V',
            -- open/close directories
            ['l'] = { '<cmd>lua require("drex.elements").expand_element()<CR>', { desc = 'expand element' } },
            ['h'] = { '<cmd>lua require("drex.elements").collapse_directory()<CR>', { desc = 'collapse directory' } },
            ['<right>'] = { '<cmd>lua require("drex.elements").expand_element()<CR>', { desc = 'expand element' } },
            ['<left>'] = {
                '<cmd>lua require("drex.elements").collapse_directory()<CR>',
                { desc = 'collapse directory' },
            },
            ['<2-LeftMouse>'] = {
                '<LeftMouse><cmd>lua require("drex.elements").expand_element()<CR>',
                {
                    desc = 'expand element',
                },
            },
            ['<RightMouse>'] = {
                '<LeftMouse><cmd>lua require("drex.elements").collapse_directory()<CR>',
                {
                    desc = 'collapse directory',
                },
            },
            -- open files in separate windows/tabs
            ['<C-v>'] = { '<cmd>lua require("drex.elements").open_file("vs")<CR>', { desc = 'open file in vsplit' } },
            ['<C-x>'] = { '<cmd>lua require("drex.elements").open_file("sp")<CR>', { desc = 'open file in split' } },
            ['<C-t>'] = {
                '<cmd>lua require("drex.elements").open_file("tabnew", true)<CR>',
                {
                    desc = 'open file in new tab',
                },
            },
            -- switch root directory
            ['<C-l>'] = {
                '<cmd>lua require("drex.elements").open_directory()<CR>',
                {
                    desc = 'open directory in new buffer',
                },
            },
            ['<C-h>'] = {
                '<cmd>lua require("drex.elements").open_parent_directory()<CR>',
                {
                    desc = 'open parent directory in new buffer',
                },
            },
            -- manual reload
            ['<F5>'] = { '<cmd>lua require("drex").reload_directory()<CR>', { desc = 'reload' } },
            -- jump around elements
            ['gj'] = {
                '<cmd>lua require("drex.actions.jump").jump_to_next_sibling()<CR>',
                {
                    desc = 'jump to next sibling',
                },
            },
            ['gk'] = {
                '<cmd>lua require("drex.actions.jump").jump_to_prev_sibling()<CR>',
                {
                    desc = 'jump to prev sibling',
                },
            },
            ['gh'] = {
                '<cmd>lua require("drex.actions.jump").jump_to_parent()<CR>',
                {
                    desc = 'jump to parent element',
                },
            },
            -- file actions
            ['s'] = { '<cmd>lua require("drex.actions.stats").stats()<CR>', { desc = 'show element stats' } },
            ['a'] = { '<cmd>lua require("drex.actions.files").create()<CR>', { desc = 'create element' } },
            ['d'] = { '<cmd>lua require("drex.actions.files").delete("line")<CR>', { desc = 'delete element' } },
            ['D'] = {
                '<cmd>lua require("drex.actions.files").delete("clipboard")<CR>',
                {
                    desc = 'delete (clipboard)',
                },
            },
            ['p'] = {
                '<cmd>lua require("drex.actions.files").copy_and_paste()<CR>',
                {
                    desc = 'copy & paste (clipboard)',
                },
            },
            ['P'] = {
                '<cmd>lua require("drex.actions.files").cut_and_move()<CR>',
                {
                    desc = 'cut & move (clipboard)',
                },
            },
            ['r'] = { '<cmd>lua require("drex.actions.files").rename()<CR>', { desc = 'rename element' } },
            ['R'] = {
                '<cmd>lua require("drex.actions.files").multi_rename("clipboard")<CR>',
                {
                    desc = 'rename (clipboard)',
                },
            },
            -- search
            ['/'] = { '<cmd>keepalt lua require("drex.actions.search").search()<CR>', { desc = 'search' } },
            -- add/remove elements from clipboard
            ['M'] = { '<cmd>DrexMark<CR>', { desc = 'mark element' } },
            ['u'] = { '<cmd>DrexUnmark<CR>', { desc = 'unmark element' } },
            ['m'] = { '<cmd>DrexToggle<CR>', { desc = 'toggle element' } },
            ['cc'] = { '<cmd>lua require("drex.clipboard").clear_clipboard()<CR>', { desc = 'clear clipboard' } },
            ['cs'] = { '<cmd>lua require("drex.clipboard").open_clipboard_window()<CR>', { desc = 'edit clipboard' } },
            -- string copy utilities
            ['y'] = { '<cmd>lua require("drex.actions.text").copy_name()<CR>', { desc = 'copy element name' } },
            ['Y'] = {
                '<cmd>lua require("drex.actions.text").copy_relative_path()<CR>',
                {
                    desc = 'copy element relative path',
                },
            },
            ['<C-y>'] = {
                '<cmd>lua require("drex.actions.text").copy_absolute_path()<CR>',
                {
                    desc = 'copy element absolute path',
                },
            },
        },
        ['v'] = {
            -- file actions
            ['d'] = { ':lua require("drex.actions.files").delete("visual")<CR>', { desc = 'delete elements' } },
            ['r'] = { ':lua require("drex.actions.files").multi_rename("visual")<CR>', { desc = 'rename elements' } },
            -- add/remove elements from clipboard
            ['M'] = { ':DrexMark<CR>', { desc = 'mark elements' } },
            ['u'] = { ':DrexUnmark<CR>', { desc = 'unmark elements' } },
            ['m'] = { ':DrexToggle<CR>', { desc = 'toggle elements' } },
            -- string copy utilities
            ['y'] = { ':lua require("drex.actions.text").copy_name(true)<CR>', { desc = 'copy element names' } },
            ['Y'] = {
                ':lua require("drex.actions.text").copy_relative_path(true)<CR>',
                { desc = 'copy element relative paths' },
            },
            ['<C-y>'] = {
                ':lua require("drex.actions.text").copy_absolute_path(true)<CR>',
                {
                    desc = 'copy element absolute paths',
                },
            },
        },
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
            "Invalid icon value for '"
                .. name
                .. "': '"
                .. value
                .. "' icon has to be non-nil, can not be blank and must not contain ' ', '/' or '\\' characters!",
            vim.log.levels.ERROR,
            { title = 'DREX' }
        )
        return false
    end
    return true
end

---Helper function to check for supported `window_picker` labels
---@param labels string List of labels to validate
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
            'Found invalid characters for `drawer.window_picker.labels`: "'
                .. table.concat(errors, '')
                .. '" fall back to default!',
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
            local test_data = { { 'x', 'file' }, { 'y', 'link' }, { 'z', 'directory' } }
            local status_ok, error = pcall(table.sort, test_data, sorting)
            if not status_ok then
                vim.notify(
                    'The provided sorting function throws an error: "' .. error .. '" fall back to default!',
                    vim.log.levels.ERROR,
                    { title = 'DREX' }
                )
                return false
            end
        else
            vim.notify(
                'The provided sorting is not a `function`, fall back to default!',
                vim.log.levels.ERROR,
                { title = 'DREX' }
            )
            return false
        end
    end

    return true
end

---Helper function to check for valid keybinding definitions
---Keybindings can be a string, a function or a list containing the binding plus an option table (two elements are required)
---@param keybindings table A list of keybindings to validate
---@return boolean
local function validate_keybindings(keybindings)
    local errors = {}
    local error_template = 'DREX - mode: %s keybinding: %s - %s'

    for mode, bindings in pairs(keybindings) do
        for key, binding in pairs(bindings) do
            if binding then
                local t = type(binding)
                if t == 'string' or t == 'function' then
                -- do nothing
                elseif t == 'table' then
                    if type(binding[1]) ~= 'string' and type(binding[1]) ~= 'function' then
                        table.insert(
                            errors,
                            error_template:format(mode, key, 'first element has to be a function or string')
                        )
                    end

                    if type(binding[2]) ~= 'table' then
                        table.insert(errors, error_template:format(mode, key, 'second element has to be a table'))
                    end
                else
                    table.insert(
                        errors,
                        error_template:format(mode, key, 'value has to be a string, a function or a list (' .. t .. ')')
                    )
                end
            end
        end
    end

    if #errors > 0 then
        vim.notify(
            'There are problems with the keybindings, fall back to default!\n' .. table.concat(errors, '\n'),
            vim.log.levels.WARN,
            { title = 'DREX' }
        )
        return false
    end

    return true
end

---Helper function to check for a valid actions configuration
---@param actions table The configuration table to validate
---@return boolean
local function validate_actions_config(actions)
    local errors = {}
    if actions then
        local delete_cmd = vim.tbl_get(actions, 'files', 'delete_cmd')
        if delete_cmd then
            local type = type(delete_cmd)
            if type == 'string' and vim.fn.executable(delete_cmd) == 0 then
                table.insert(
                    errors,
                    'The custom delete command "' .. delete_cmd .. '" does not exist (or is not executable)'
                )
            elseif type ~= 'function' and type ~= 'string' then
                table.insert(errors, 'Invalid type "' .. type .. '" for custom delete command')
            end
        end
    end

    if vim.tbl_count(errors) > 0 then
        vim.notify(
            'There are problems with the actions configuration, fall back to the default settings!\n'
                .. table.concat(errors, '\n'),
            vim.log.levels.WARN,
            { title = 'DREX' }
        )
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

    -- check for valid keybindings
    if not validate_keybindings(M.options.keybindings) then
        M.options.keybindings = defaults.keybindings
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

    -- check for custom actions configuration
    if not validate_actions_config(M.options.actions) then
        M.options.actions = defaults.actions
    end

    if M.options.hijack_netrw then
        require('drex.config.netrw').init()
    end
end

---Set all default keybindings for the given DREX buffer
---Called automatically by `ftplugin/drex.lua`
---Only intended for internal usage within the DREX plugin
---@param buffer number Buffer ID
function M.set_default_keybindings(buffer)
    for mode, bindings in pairs(M.options.keybindings) do
        for lhs, rhs in pairs(bindings) do
            -- check if `rhs` is truthy, users can set rhs to `false` to disable certain default bindings
            if rhs then
                local opts = {
                    buffer = buffer,
                    silent = true,
                    nowait = true,
                }

                -- check for passed options table
                if type(rhs) == 'table' then
                    opts = vim.tbl_extend('force', opts, rhs[2])
                    rhs = rhs[1]
                end

                vim.keymap.set(mode, lhs, rhs, opts)
            end
        end
    end
end

return M
