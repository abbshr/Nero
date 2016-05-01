Nero
===

实现Archangel核心功能的系统, 即API Gateway.

在Node层面压榨性能使并发量/系统负载率比值尽量提高, 尽量保持原生Node.js网络I/O的高效特性.
Nero本身(部分插件可能会产生额外的网络I/O)工作时并不会做除网络请求外的其他I/O操作, 所有的配置数据由代理进程计算更新子集,
并通过IPC PIPE周期性推送给工作进程(临时做法, hive-fs完善后可能换共享内存).
基于插件的请求/响应流程极大扩展丰富了Nero作为API Gateway的灵活性, 可以在req/res两个阶段配置不同的插件.
当内置插件(编写中)无法满足业务需求时, Nero允许开发者订制自己的第三方插件.
插件系统支持动态配置, 允许Nero插件热更新, 即在不重启的情况下增删或修改插件.

```bash
bin/nero
```

Writting plugins
===

插件目录位于`./plugins`, 使用自定义扩展前需要在`./etc/plugins.yaml`中注册新的名字和查找路径.

`./etc/plugins.yaml`中的插件路径相对于`./plugins`.

在`./etc/Nero.yaml`配置文件的`request_phase`和`response_phase`字段里可以选择性启用/禁用`./etc/plugins.yaml`中的插件.

例如:
```coffee
# 编写一个返回调用时间戳的插件
# 文件: ./plugins/ts/index.coffee

class ResTimestamp
  pluginName: 'res-timestamp'
  handle: (req, res, next) ->
    # handle中可以使用Nero的全局配置对象@settings, 
    # 包含当前调用的服务名字, 请求参数, 上游应用服务器地址, 该插件的配置
    
    # 当前插件的配置:
    # cfg = req.cfg[@pluginName]
    
    # 不需要在handle里检查该插件是否被启用以及对应服务是否配置了该插件
    # 空配置和禁用状态会被直接pass
    
    res.end JSON.stringify msg: timestamp: Date.now()

module.exports = -> new ResTimestamp()
```

Subscribe the FeedStream
===

Nero中的数据需要通过Leviathan取得, 目前做法是Nero agent订阅Leviathan的feed stream服务实时差异集合, 周期性推送更新本地数据.