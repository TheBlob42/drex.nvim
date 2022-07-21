local config = require('drex.config')

config.set_default_keybindings(0)

if config.options.hide_cursor then
    require('drex.config.cursor').init()
end
