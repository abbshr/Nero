{plugin: {load_prefix}} = require '../../etc/Nero'
plugin_lst = require '../../etc/plugins'
Scaffold = require './scaffold'
path = require 'path'
cwd = process.cwd()

concatDir = (pluginName) ->
  dir_suffix = plugin_lst[pluginName]
  unless dir_suffix?
    throw new Error """
      plugin <#{pluginName}> not found, make sure it has been installed correctly
    """
  dir = path.join cwd, load_prefix, dir_suffix

class HotConf

  exec: (pluginName, dir) ->
    try
      plugin = require(dir)()
    catch e
      throw new Error """
        can not initialize the specified plugin: <#{pluginName}> => #{dir}
      """
    plugin._dir = dir
    plugin

  load: (pluginName, cached = yes) ->
    plugin = @exec pluginName, concatDir pluginName
    delete require.cache[plugin._dir] unless cached
    plugin

  unload: (pluginName) ->
    dir = concatDir pluginName
    delete require.cache[dir]
    dir

  reload: (pluginName) ->
    @exec pluginName, @unload pluginName
  
  createFn: (pluginName, settings) ->
    plugin = @load pluginName, no
    scaffold = Scaffold plugin, settings
    scaffold.fn
    
module.exports = HotConf
  