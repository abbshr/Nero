{prefix, plugins: plugins_lst} = require '../etc/plugins-lst'

concatDir = (pluginName) ->
  unless pluginName of plugins_lst
    throw new Error """
      plugin [#{pluginName}] not found, make sure it has been installed correctly
    """
  dir = path.join __dirname, prefix, plugins_lst[pluginName]

class HotConf
   
  @load: (pluginName) ->      
    dir = concatDir pluginName
    
    try
      Plugin = require dir
    catch e
      throw new Error """
        can not initialize the specified plugin: #{dir}
      """
    Plugin._dir = dir
    Plugin
    
  @unload: (pluginName) ->
    dir = concatDir pluginName
    delete require.cache[dir]
    dir
  
  @reload: (pluginName) ->
    dir = @unload pluginName
    Plugin = require dir
  
  @createFn: (pluginName, settings) ->
    Plugin = @load pluginName
    plugin = new Plugin settings
    
module.exports = HotConf
  