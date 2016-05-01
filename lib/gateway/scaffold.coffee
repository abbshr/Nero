class Scaffold

  constructor: (plugin, @settings) ->
    {@pluginName} = plugin
    @handle = plugin.handle.bind plugin
    plugin.settings = @settings
    @enabled = on
  
  fn: (req, res, next) ->
    # 插件执行前检查启用情况
    unless @enabled
      return next()
    
    # 每个插件函数内部可以访问api的全局设置`@settings`来获取当前插件的配置
    {"#{req.serviceName}": {plugins}} = @settings
    
    unless plugins?[@pluginName]
      return next()
    
    req.cfg[@pluginName] = plugins[@pluginName]
    # 执行插件逻辑
    @handle req, res, next

# 导出插件的一个实例对象
module.exports = (plugin, settings) ->
  new Scaffold plugin, settings