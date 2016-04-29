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
   
  load: (pluginName) ->      
    dir = concatDir pluginName
    
    try
      Plugin = require dir
    catch e
      throw new Error """
        can not initialize the specified plugin: <#{pluginName}> => #{dir}
      """
    Plugin._dir = dir
    Plugin
    
  unload: (pluginName) ->
    dir = concatDir pluginName
    delete require.cache[dir]
    dir
  
  reload: (pluginName) ->
    dir = HotConf::unload pluginName
    Plugin = require dir
  
  createFn: (pluginName, settings) ->
    Plugin = HotConf::load pluginName
    plugin = new Plugin settings
    
module.exports = HotConf
  