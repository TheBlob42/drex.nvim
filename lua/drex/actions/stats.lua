local M = {}

local api = vim.api
local luv = vim.loop
local utils = require('drex.utils')

---Print file/directory details for the current element
--- - created, accessed and modified time
--- - file size
--- - permissions
function M.stats()
    utils.check_if_drex_buffer(0)

    local element = utils.get_element(api.nvim_get_current_line())
    local details = luv.fs_lstat(element)

    if not details then
        vim.notify("Could not read details for '" .. element .. "'!", vim.log.levels.ERROR, { title = 'DREX' })
        return
    end

    local created = os.date('%c', details.birthtime.sec)
    local accessed = os.date('%c', details.atime.sec)
    local modified = os.date('%c', details.mtime.sec)

    -- convert file/directory size in bytes into human readable format (SI)
    -- source: https://stackoverflow.com/a/3758880
    local size
    local bytes = details.size
    if details.size > -1000 and details.size < 1000 then
        size = bytes .. 'B'
    else
        local index = 1
        -- kilo, mega, giga, tera, peta, exa
        local prefixes = { 'k', 'M', 'G', 'T', 'P', 'E' }
        while bytes <= -999950 or bytes >= 999950 do
            bytes = bytes / 1000
            index = index + 1
        end
        size = string.format('%.1f%sB', bytes / 1000, prefixes[index])
    end

    -- format positive byte size with decimal delimiters
    -- e.g. 123456789 --> 123,456,789
    -- source: https://stackoverflow.com/a/11005263
    local formatted_byte_size = tostring(details.size):reverse():gsub('%d%d%d', '%1,'):reverse():gsub('^,', '')

    -- mask off the file type portion of mode (using 07777)
    -- print as octal number to see the real permissions
    local mode = string.format('%o', bit.band(details.mode, tonumber('07777', 8)))

    -- cycle through the mode digits to extract the access permissions (read, write & execute)
    -- for every class (user, group & others) into a single human readable string
    -- for example:
    -- --> mode = 664
    -- --> access_permissions = rw-rw-r--
    local access_permissions = ''
    for c in mode:gmatch('.') do
        local num = tonumber(c)
        local class = ''

        -- check for "read" access
        if (num - 4) >= 0 then
            class = class .. 'r'
            num = num - 4
        else
            class = class .. '-'
        end

        -- check for "write" access
        if (num - 2) >= 0 then
            class = class .. 'w'
            num = num - 2
        else
            class = class .. '-'
        end

        -- check for "execute" access
        if (num - 1) >= 0 then
            class = class .. 'x'
            num = num - 1
        else
            class = class .. '-'
        end

        access_permissions = access_permissions .. class
    end

    utils.echo(table.concat({
        'Details for ' .. details.type .. " '" .. element .. "'",
        ' ',
        'Size:         ' .. size .. ' (' .. formatted_byte_size .. ' bytes)',
        'Permissions:  ' .. access_permissions .. ' (' .. mode .. ')',
        'Created:      ' .. created,
        'Accessed:     ' .. accessed,
        'Modified:     ' .. modified,
    }, '\n'))
end

return M
