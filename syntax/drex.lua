if vim.b.current_syntax then
    return
end

local utils = require('drex.utils')
local config = require('drex.config')
local clipboard = require('drex.clipboard').clipboard

local esc = utils.vim_escape
local sep = utils.path_separator

-- conceal full paths (like `vim-dirvish`)
vim.cmd([[syntax match DrexPath "\([a-zA-Z]:\)\?\]] .. sep .. [[\(.*\]] .. sep .. [[\)\?" conceal cchar= ]])

-- syntax highlighting for nested files
for element, _ in pairs(clipboard) do
    vim.cmd([[syntax region DrexSelected start="]] .. esc(element) .. [[/" end="$" contains=DrexPath]])
end

-- syntax highlighting for explicitly marked files
for element, _ in pairs(clipboard) do
    vim.cmd([[syntax match DrexMarked "]] .. esc(element) .. [[$" contains=DrexPath]])
end

-- syntax highlighting for different elements to separate them from regular files
local icons = config.options.icons
local syntax = 'syntax region %s start="%s" end="$" contains=DrexPath,DrexSelected,DrexMarked keepend'
vim.cmd(syntax:format('DrexDir', icons.dir_closed))
vim.cmd(syntax:format('DrexDir', icons.dir_open))
vim.cmd(syntax:format('DrexLink', icons.link))
vim.cmd(syntax:format('DrexOthers', icons.others))

if config.options.colored_icons then
    local dev_icons_ok, dev_icons = pcall(require, 'nvim-web-devicons')
    if dev_icons_ok then
        for _, icon in pairs(dev_icons.get_icons()) do
            vim.cmd('syntax match DevIcon' .. icon.name .. ' "' .. icon.icon .. '"')
        end
    end
end

vim.b.current_syntax = 'drex'
