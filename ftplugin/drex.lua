local config = require('drex.config')

config.set_default_keybindings(0)

if config.config.hide_cursor then
    require('drex.cursor').init()
end
