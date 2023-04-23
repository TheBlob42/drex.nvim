local M = {}

local api = vim.api
local luv = vim.loop
local utils = require('drex.utils')
local config = require('drex.config')

---Save the connections between "file system paths" which are being monitored by LUV and DREX buffers
---Each entry connects a `path` (key) with a table (value) which contains:
---- A list of DREX buffers that display the given `path` (as root or as a sub-tree)
---- A function to "stop" a LUV event handler if it's not needed anymore
---- A table of post functions per buffer which should be executed once after the next path reload
---  - This is currently used for focusing an element after creation or renaming
---- A timer to queue fs events for this `path`
---
---Furthermore there are some utility functions to ease the interaction with this special table:
---`_add_path`, `_remove_path`, `_add_buffer`, `_remove_buffer`
---
---Example:
---<pre>
---{
---  ["/home/user"] = {
---    buffers = { 2, 13, 45 },
---    stop = function()
---      vim.loop.fs_event_stop(handler)
---    end,
---    post_fn = {
---      [2] = function() focus_element() end,
---    },
---    timer = vim.loop.new_timer(),
---  }
---}
---</pre>
local connections = {}

---Save a function `fn` to be executed once the next time `path` has been reloaded in `buf`
---
---This will only save the given function if `path` is monitored for file events AND `buf` is registered for it
---In this case the return value is `true` otherwise this function returns `false`
---@param path string The path which should be monitored
---@param buf number The buffer that should be registered
---@param fn function Function that should be executed ONCE after the next reload of `path` in `buf`
---@return boolean
function M.post_next_reload(path, buf, fn)
    if connections[path] and connections[path].buffers[buf] then
        connections[path].post_fn[buf] = fn
        return true
    end

    return false
end

---Add a new `path` entry to the `connections` table
---@param path string File system path which should being monitored
---@param event_listener userdata LUV file system event for the given `path`
---@vararg number Buffer IDs
connections._add_path = function(path, event_listener, ...)
    -- "unpack" vararg buffers into a set
    local buffers = {}
    for _, buf in ipairs({ ... }) do
        buffers[buf] = true
    end

    connections[path] = {
        buffers = buffers,
        stop = function()
            luv.fs_event_stop(event_listener)
        end,
        post_fn = {},
        timer = luv.new_timer(),
    }
end

---Stop monitoring a given `path` and remove its entry from the `connections` table
---@param path string Path to stop and remove
connections._remove_path = function(path)
    if connections[path] then
        connections[path].stop()
        connections[path] = nil
    end
end

---Add a `buffer` to a specific `path` entry
---@param path string File system path
---@param buffer number Buffer ID
connections._add_buffer = function(path, buffer)
    if connections[path] then
        connections[path].buffers[buffer] = true
    end
end

---Remove a `buffer` from a specific `path` entry
---@param path string File system path
---@param buffer number Buffer ID
connections._remove_buffer = function(path, buffer)
    if connections[path] then
        connections[path].buffers[buffer] = nil
    end
end

---Monitor for changes inside a directory represented by `path`
---Register the given `buffer` as a watcher for it
---@param buffer number Buffer handle, or 0 for current buffer
---@param path string Directory which should be monitored for changes
function M.watch_directory(buffer, path)
    if buffer == 0 then
        buffer = api.nvim_get_current_buf() -- get "actual" buffer id
    end

    -- if a connection is already registered for path, just add the new buffer
    if connections[path] then
        connections._add_buffer(path, buffer)
        return
    end

    local event_listener = luv.new_fs_event()
    -- default values for all supported flags
    local flags = {
        watch_entry = false, -- watch for all events in the given directory (not implemented)
        stat = false, -- fall back to poll 'stat()' as a fallback (not implemented)
        recursive = false, -- also check for changes in subdirectories (not supported on Linux)
    }

    connections._add_path(path, event_listener, buffer)

    local event_callback = vim.schedule_wrap(function(error, _, event)
        if error then
            -- todo? log into some debug file
            return
        end

        -- path entry was already stopped and deleted
        if not connections[path] then
            return
        end

        if connections[path].timer:get_due_in() > 0 then
            return
        end

        connections[path].timer:start(
            100,
            0,
            vim.schedule_wrap(function()
                -- a 'rename' event is also send if a directory was deleted
                if event.rename and not luv.fs_access(path, 'r') then
                    -- reload all buffers that displayed `path` (all "parents")
                    local parent_path = vim.fn.fnamemodify(path, ':h:h') .. utils.path_separator

                    for buf, _ in pairs(connections[path].buffers) do
                        if vim.fn.bufexists(buf) ~= 0 then
                            if utils.get_root_path(buf) == path then
                                -- since the directory does not exists anymore delete the corresponding DREX buffer
                                api.nvim_buf_delete(buf, { force = true })
                            else
                                -- if the `parent_path` does still exist, reload the corresponding buffer
                                if luv.fs_access(parent_path, 'r') then
                                    require('drex').reload_directory(buf, parent_path)
                                end
                            end
                        end
                    end

                    local clipboard = require('drex.clipboard')
                    for element, _ in pairs(clipboard.clipboard) do
                        if vim.startswith(element, path) then
                            clipboard.delete_from_clipboard(element)
                        end
                    end

                    connections._remove_path(path)
                    return
                end

                for buf, _ in pairs(connections[path].buffers) do
                    if vim.fn.bufexists(buf) == 0 then
                        connections._remove_buffer(path, buffer)
                    else
                        -- reload `path` within buffer
                        require('drex').reload_directory(buf, path)

                        -- check if there is a saved post fn and execute it
                        if connections[path].post_fn[buf] then
                            pcall(connections[path].post_fn[buf])
                            connections[path].post_fn[buf] = nil
                        end
                    end
                end

                -- check clipboard for elements that have been renamed or deleted outside of Neovim
                local clipboard = require('drex.clipboard')
                for element, _ in pairs(clipboard.clipboard) do
                    if vim.startswith(element, path) then
                        if not luv.fs_lstat(element) then
                            clipboard.delete_from_clipboard(element)
                        end
                    end
                end

                -- if no buffers are connected anymore, remove the whole path
                if vim.tbl_count(connections[path].buffers) == 0 then
                    connections._remove_path(path)
                end
            end)
        )
    end)

    luv.fs_event_start(event_listener, path, flags, event_callback)
end

---Remove `buffer` as a watcher for the given directory represented by `path`
---@param buffer number Buffer handle, or 0 for current buffer
---@param path string Directory which should not be monitored anymore
function M.unwatch_directory(buffer, path)
    if buffer == 0 then
        buffer = api.nvim_get_current_buf() -- get "actual" buffer id
    end

    for p, _ in pairs(connections) do
        if vim.startswith(p, path) then -- check all sub-paths as well
            connections._remove_buffer(p, buffer)

            -- if no buffers are connected anymore, remove the whole path
            if vim.tbl_count(connections[p].buffers) == 0 then
                connections._remove_path(p)
            end
        end
    end
end

---Scan the contents of the given directory and format it for the usage in a DREX buffer
---If the given `path` does not exist or is not a directory this function returns `nil`
---@param path string Directory which should be scanned for its content
---@param root_path string? (Optional) Used to calculate the indentation for the usage as sub-tree
---@return table? content Directory content lines (formatted) or `nil`
function M.scan_directory(path, root_path)
    -- ensure that it's an absolute path
    path = vim.fn.fnamemodify(path, ':p')

    -- ensure that the target is an existing directory
    if not utils.points_to_existing_directory(path) then
        print("'" .. path .. "' does not point to an existing directory!")
        return
    end

    local data, error = luv.fs_scandir(path)
    if error then
        print(error)
        return
    end

    -- if given a `root_path` calculate the needed indentation
    local indentation = '  '
    if root_path and path ~= root_path then
        local relative_path = path:gsub('^' .. vim.pesc(root_path), '')
        local _, count = relative_path:gsub(utils.path_separator, '')
        indentation = indentation .. string.rep('  ', count)
    end

    local content = {}
    while true do
        local name, type = luv.fs_scandir_next(data)
        if not name then
            break
        end

        table.insert(content, { name, type })
    end

    if config.options.sorting then
        table.sort(content, config.options.sorting)
    end

    local icons_loaded, icons = pcall(require, 'nvim-web-devicons')
    for i = 1, #content do
        local name, type = content[i][1], content[i][2]
        local icon = config.options.icons.file_default

        if type == 'directory' then
            icon = config.options.icons.dir_closed
        elseif type == 'link' then
            icon = config.options.icons.link
        elseif type ~= 'file' then
            icon = config.options.icons.others
        elseif icons_loaded then
            icon = icons.get_icon(name, vim.fn.fnamemodify(name, ':e'), { default = true })
        end

        content[i] = indentation .. icon .. ' ' .. path .. name
    end

    return content
end

return M
