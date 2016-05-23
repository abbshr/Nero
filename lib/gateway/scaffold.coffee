class Scaffold

  constructor: (plugin, @settings) ->
    {@pluginName, @base} = plugin
    @handle = plugin.handle.bind plugin
    plugin.settings = @settings
    @enabled = on
  
  fn: (req, res, next) ->
    # 插件执行前检查启用情况
    unless @enabled
      return next()
    
    # 每个插件函数内部可以访问api的全局设置`@settings`来获取当前插件的配置
    {"#{req.serviceName}": {plugins}} = @settings
    
    req.cfg = plugins[@pluginName]
    
    # 对于基础插件都要执行
    if @base
      return @handle req, res, next
    
    # 否则按API配置执行插件
    unless plugins?[@pluginName]
      return next()

    # 执行插件逻辑
    @handle req, res, next

# 导出插件的一个实例对象
module.exports = (plugin, settings) ->
  new Scaffold plugin, settings