{plugin: {load_prefix}} = require '../../etc/Nero'
plugin_lst = require '../../etc/plugins'
path = require 'path'
cwd = process.cwd()

concatDir = (pluginName) ->
  unless pluginName of plugin_lst
    throw new Error """
      plugin <#{pluginName}> not found, make sure it has been installed correctly
    """
  dir = path.join cwd, load_prefix, pluginName

class HotConf

  exec: (pluginName, dir) ->
    try
      Plugin = require dir
    catch e
      throw new Error """
        can not initialize the specified plugin: <#{pluginName}> => #{dir}
      """
    Plugin._dir = dir
    Plugin

  load: (pluginName, cached = yes) ->
    Plugin = @exec pluginName, concatDir pluginName
    delete require.cache[Plugin._dir] unless cached
    Plugin

  unload: (pluginName) ->
    dir = concatDir pluginName
    delete require.cache[dir]
    dir

  reload: (pluginName) ->
    @exec pluginName, @unload pluginName
  
  createFn: (pluginName, settings) ->
    Plugin = @load pluginName, no
    plugin = new Plugin settings
    plugin.pluginName = pluginName
    plugin
    
module.exports = HotConf
  