local M = {}

local api = vim.api
local utils = require('drex.utils')
local clipboard = require('drex.clipboard')

local ns_id = api.nvim_create_namespace('drex-search')
local search_error_id = 1

---Simple wrapper around `vim.api.nvim_replace_termcodes` for easier usage
---@param s string
---@return string
local function t(s)
    return api.nvim_replace_termcodes(s, true, true, true)
end

---Some default search actions, ready to use
M.actions = {}

---Abort and close the search
---@return boolean
function M.actions.close()
    return true
end

---Move the cursor to the next search hit
function M.actions.goto_next()
    local row, col = unpack(api.nvim_win_get_cursor(0))
    -- avoid error when cursor pos it out of window bounds
    pcall(api.nvim_win_set_cursor, 0, { row + 1, col })
end

---Move the cursor to the previous search hit
function M.actions.goto_prev()
    local row, col = unpack(api.nvim_win_get_cursor(0))
    -- avoid error when cursor pos it out of window bounds
    pcall(api.nvim_win_set_cursor, 0, { row - 1, col })
end

---Delete the last entered character of the search input
---If the search input is empty already, end the search
---@param args table
---@return boolean
function M.actions.backspace(args)
    if #args.input == 0 then
        return true
    end
    return args.input:sub(1, -2)
end

---Close the search and jump to the selected element in the original DREX buffer
---If the selected element does not exists (e.g. was deleted in the meantime) this outputs a warning
---@param args table
---@return boolean
function M.actions.jump(args)
    local search_line = api.nvim_get_current_line()

    if search_line == '' then
        vim.notify('No match found for "' .. args.input .. '"!', vim.log.levels.WARN, {})
        return false
    end

    local row
    for i, line in ipairs(api.nvim_buf_get_lines(args.src_buf, 0, -1, false)) do
        if line == search_line then
            row = i
            break
        end
    end

    if row then
        api.nvim_set_current_buf(args.src_buf)
        local top = vim.fn.line('w0')
        local bottom = vim.fn.line('w$')
        api.nvim_win_set_cursor(0, { row, 0 })

        -- if line was not visible beforehand, center view
        if row < top or row > bottom then
            vim.cmd('normal! zz')
        end

        return true
    end

    vim.notify(
        'Could not find "' .. utils.get_name(search_line) .. '"! Maybe something changed in the meantime...',
        vim.log.levels.WARN,
        {}
    )
    return false
end

---Mark all current visible elements from the search buffer and add them to the DREX clipboard
---@return boolean
function M.actions.mark_all()
    for _, line in ipairs(api.nvim_buf_get_lines(0, 0, -1, false)) do
        if line ~= '' then
            clipboard.add_to_clipboard(utils.get_element(line))
        end
    end

    utils.reload_drex_syntax()

    return true
end

local default_config = {
    fuzzy = true,
    case_sensitive = false,
    keybindings = {
        ['<C-n>'] = M.actions.goto_next,
        ['<C-p>'] = M.actions.goto_prev,
        ['<CR>'] = M.actions.jump,
        ['<ESC>'] = M.actions.close,
        ['<C-c>'] = M.actions.close,
        ['<BS>'] = M.actions.backspace,
        ['<A-m>'] = M.actions.mark_all,
    },
}

---Execute a live search in the current DREX buffer
---Pass `config` to overwrite the default values:
---<pre>
---{
---   fuzzy = true,
---   case_sensitive = false,
---   keybindings = {
---      ['<C-n>'] = require('drex.actions.search').actions.goto_next,
---      ['<C-p>'] = require('drex.actions.search').actions.goto_prev,
---      ['<CR>']  = require('drex.actions.search').actions.jump,
---      ['<ESC>'] = require('drex.actions.search').actions.close,
---      ['<C-c>'] = require('drex.actions.search').actions.close,
---      ['<BS>']  = require('drex.actions.search').actions.backspace,
---      ['<A-m>'] = require('drex.actions.search').actions.mark_all,
---   }
---}
---</pre>
---For more information see `:help drex-search`
---@param config table
function M.search(config)
    config = vim.tbl_deep_extend('force', default_config, config or {})
    local src_buf = api.nvim_get_current_buf()
    local view = vim.fn.winsaveview()
    local content = api.nvim_buf_get_lines(src_buf, 0, -1, false)

    local buf = vim.api.nvim_create_buf(false, true)
    local matches = {}

    api.nvim_buf_set_lines(buf, 0, -1, false, content)
    api.nvim_buf_set_name(buf, 'DREX Search')
    api.nvim_buf_set_option(buf, 'syntax', 'drex')
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    api.nvim_set_current_buf(buf)
    vim.fn.winrestview(view)

    -- check keybindings and convert keys into terminal codes
    local keybindings = {}
    for key, binding in pairs(config.keybindings) do
        if type(binding) ~= 'function' then
            vim.notify('Keybinding for "' .. key .. '" is not a function!', vim.log.levels.WARN, {})
        else
            keybindings[t(key)] = binding
        end
    end

    -- copied from `drex.lua` -> `on_enter`
    vim.opt_local.wrap = false
    vim.opt_local.cursorline = true
    vim.opt_local.conceallevel = 3
    vim.opt_local.concealcursor = 'nvc'
    vim.opt_local.spell = false

    local post_fn
    local input = ''
    vim.cmd('redraw')
    utils.echo('Filter for > ' .. input, false)
    while true do
        local ok, nr = pcall(vim.fn.getchar)
        if not ok then
            break
        end

        -- args passed to every function defined in `config.keybindings`
        local args = {
            input = input,
            src_buf = src_buf,
        }

        local char = type(nr) == 'string' and nr or vim.fn.nr2char(nr)

        local binding = keybindings[char]
        if binding then
            local result = binding(args)
            if result then
                if type(result) == 'string' then
                    input = result
                end

                if type(result) == 'function' then
                    post_fn = result
                    break
                end

                if type(result) == 'boolean' then
                    break -- has to be "true" at this point
                end
            end
        elseif type(nr) == 'number' and (nr < 32 or nr == 127) then
            -- ignore
        else
            input = input .. char
        end

        for _, match in ipairs(matches) do
            pcall(vim.fn.matchdelete, match)
        end
        matches = {}
        api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

        local new_content
        local case_rgx_postfix = config.case_sensitive and [[\C]] or [[\c]]

        if config.fuzzy then
            local prev_chars_rgx = ''
            for _, c in ipairs(vim.split(input, '')) do
                c = utils.vim_escape(c)
                table.insert(
                    matches,
                    vim.fn.matchadd(
                        'Search',
                        [[/.\{-}]] .. prev_chars_rgx .. [[\zs]] .. c .. [[\(.*\/\)\@!]] .. case_rgx_postfix
                    )
                )
                prev_chars_rgx = prev_chars_rgx .. c .. [[.\{-}]]
            end

            local rgx = vim.regex(prev_chars_rgx .. case_rgx_postfix)

            new_content = vim.tbl_filter(function(line)
                local element = utils.get_name(line)
                return rgx:match_str(element)
            end, content)
        else
            local match_ok, match =
                pcall(vim.fn.matchadd, 'Search', [[/.\{-}\zs]] .. input .. [[\(.*\/\)\@!]] .. case_rgx_postfix)
            if match_ok then
                table.insert(matches, match)
            end

            local rgx_ok, rgx = pcall(vim.regex, input .. case_rgx_postfix)
            if rgx_ok then
                new_content = vim.tbl_filter(function(line)
                    local element = utils.get_name(line)
                    return rgx:match_str(element)
                end, content)
            else
                new_content = {}
                local error = rgx:match('.+:.+: (.*)')
                api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
                    id = search_error_id,
                    virt_text = { { 'REGEX ERROR: ' .. error, 'ErrorMsg' } },
                    line_hl_group = 'Normal', -- hide CursorLine highlighting
                    number_hl_group = 'ErrorMsg',
                    sign_hl_group = 'ErrorMsg',
                })
            end
        end

        if
            vim.tbl_isempty(new_content)
            and vim.tbl_isempty(api.nvim_buf_get_extmark_by_id(buf, ns_id, search_error_id, {}))
        then
            api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
                id = search_error_id,
                virt_text = { { 'No matches found!', 'WarningMsg' } },
                line_hl_group = 'Normal', -- hide CursorLine highlighting
                number_hl_group = 'WarningMsg',
                sign_hl_group = 'WarningMsg',
            })
        end

        api.nvim_buf_set_lines(buf, 0, -1, false, new_content)
        vim.cmd('redraw')
        utils.echo('Filter for > ' .. input, false)
    end

    api.nvim_set_current_buf(src_buf)

    -- delete match highlights & clear command line
    for _, match in ipairs(matches) do
        pcall(vim.fn.matchdelete, match)
    end
    utils.echo(' ', false)
    vim.cmd('redraw')

    if post_fn then
        post_fn()
    end
end

return M
