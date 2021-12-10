if vim.fn.exists('b:current_syntax') ~= 0 then
    return
end

local sep = require('drex.utils').path_separator
-- conceal full paths (like `vim-dirvish`)
vim.cmd([[syntax match DrexPath "\([a-zA-Z]:\)\?\]]..sep..[[.*\]]..sep..[[" conceal cchar= ]])

local clipboard = require('drex.actions').clipboard
local esc = require('drex.utils').vim_escape

-- syntax highlighting for nested files
for element, _ in pairs(clipboard) do
    vim.cmd([[syntax region DrexSelected start="]] .. esc(element) .. [[/" end="$" contains=DrexPath]])
end

-- syntax highlighting for explicitly marked files
for element, _ in pairs(clipboard) do
    vim.cmd([[syntax match DrexMarked "]] .. esc(element) .. [[$" contains=DrexPath]])
end

local icons = require('drex.config').config.icons
-- syntax highlighting for directories to easier separate them from regular files
vim.cmd('syntax region DrexDir start="' .. icons.dir_closed .. '" end="$" contains=DrexPath,DrexSelected,DrexMarked keepend')
vim.cmd('syntax region DrexDir start="' .. icons.dir_open   .. '" end="$" contains=DrexPath,DrexSelected,DrexMarked keepend')

vim.b.current_syntax = 'drex'
