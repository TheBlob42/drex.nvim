if vim.fn.has('nvim-0.7') ~= 1 then
    return
end

if vim.g.loaded_drex then
    return
end

local drex = require('drex')
local utils = require('drex.utils')
local drawer = require('drex.drawer')
local actions = require('drex.actions')

-- ~~~~~~~~~~~~~~~~
-- ~ user commands
-- ~~~~~~~~~~~~~~~~

vim.api.nvim_create_user_command('Drex', function(args)
    drex.open_directory_buffer(args.args)
end, {
    desc = 'Open a DREX buffer',
    nargs = '?',
    complete = 'dir',
})

vim.api.nvim_create_user_command('DrexDrawerOpen', drawer.open, {
    desc = 'Open and focus the DREX drawer window'
})

vim.api.nvim_create_user_command('DrexDrawerClose', drawer.close, {
    desc = 'Close the DREX drawer window'
})

vim.api.nvim_create_user_command('DrexDrawerToggle', drawer.toggle, {
    desc = 'Toggle the DREX drawer window'
})

vim.api.nvim_create_user_command('DrexDrawerFindFile', function()
    drawer.find_element('%', false, true)
end, {
    desc = 'Jump to the current file in the DREX drawer window'
})

vim.api.nvim_create_user_command('DrexDrawerFindFileAndFocus', function()
    drawer.find_element('%', true, true)
end, {
    desc = 'Jump to the current file in the DREX drawer window and focus it'
})

vim.api.nvim_create_user_command('DrexMark', function(args)
    actions.mark(args.line1, args.line2)
end, {
    desc = 'Mark the element(s) and add them to the DREX clipboard',
    range = true,
})

vim.api.nvim_create_user_command('DrexUnmark', function(args)
    actions.unmark(args.line1, args.line2)
end, {
    desc = 'Unmark the element(s) and remove them from the DREX clipboard',
    range = true,
})

vim.api.nvim_create_user_command('DrexToggle', function(args)
    actions.toggle(args.line1, args.line2)
end, {
    desc = 'Toggle the element(s) and add or remove them from the DREX clipboard',
    range = true,
})

-- ~~~~~~~~~~~~~~~~
-- ~ configuration
-- ~~~~~~~~~~~~~~~~

vim.api.nvim_create_autocmd('SessionLoadPost', {
    desc = 'Manually reopen DREX buffers after session reload',
    pattern = 'drex://*',
    nested = true,
    callback = function()
        drex.open_directory_buffer(utils.get_root_path())
    end,
})

if require('drex.config').options.hijack_netrw then
    require('drex.config.netrw').init()
end

-- ~~~~~~~~~~~~~
-- ~ highlights
-- ~~~~~~~~~~~~~

-- differentiate directories elements
vim.api.nvim_set_hl(0, 'DrexDir', {
    default = true,
    link = 'Directory',
})

-- differentiate link elements
vim.api.nvim_set_hl(0, 'DrexLink', {
    default = true,
    link = 'Identifier',
})

-- differentiate other elements (fifo, socket, etc.)
vim.api.nvim_set_hl(0, 'DrexOthers', {
    default = true,
    link = 'SpecialChar',
})

-- explicitly marked elements
vim.api.nvim_set_hl(0, 'DrexMarked', {
    default = true,
    link = 'Substitute',
})

-- highlighting for indirectly selected items
vim.api.nvim_set_hl(0, 'DrexSelected', {
    default = true,
    link = 'Visual',
})

vim.g.loaded_drex = 1
