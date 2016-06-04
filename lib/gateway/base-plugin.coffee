Resolve = require './resolve'
url = require 'url'
logger = require('../util/logger')()

#
# Check if a request has a request body.
# A request with a body __must__ either have `transfer-encoding`
# or `content-length` headers set.
# http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.3
# 

hasbody = (req) ->
  req.headers['transfer-encoding']? or not isNaN req.headers['content-length']

BasePlugin =
  ###
    系统挂载的属性:
      req.specHeader - 在`request-head-transform`插件中生成的的自定义请求头
      req.etcs - upstream的path (即protocol://host:port之后的部分)
      req.cfg - 当前执行的插件的配置信息
      req.stageDataStream - 客户端请求携带的数据流
      req.serviceName - 服务名称
  ###
  requestFn: (service_settings) ->
    (req, res, next) ->
      # 解析serviceName
      {pathname} = url.parse req.url
      spliter = pathname.indexOf '/', 1
      if spliter is -1
        serviceName = req.serviceName = pathname[1...]
        req.etcs = '/'
      else
        serviceName = req.serviceName = pathname[1...spliter]
        req.etcs = pathname[spliter...]
      req.cfg = {}
      logger.debug "[base plugin - requestFn]", "got serviceName", serviceName
      logger.debug "service config:", service_settings[serviceName]

      if service_settings[serviceName]?.upstreams.length
        req.hasbody = hasbody req
        next()
      else
        res.statusCode = 200
        res.end JSON.stringify msg: 'upstreams not found', time: Date.now()

  forwardFn: (service_settings) ->
    (req, res, next) ->
      upstreams = service_settings[req.serviceName].upstreams
      # load balance
      i = ~~(Math.random() * upstreams.length)
      logger.debug "[base plugin - forwardFn]"
      Resolve::forward upstreams[i], req, (err, upstream_res) ->
        res.upstream_res = if err?
          err.message
        else
          JSON.parse upstream_res
        next()

  responseFn: ->
    (req, res) ->
      if res.upstream_res?
        res.write JSON.stringify upstream_res: res.upstream_res
        res.end()
      else
        res.statusCode = 200
        res.end JSON.stringify msg: 'empty body'

###
  this will exports the following functions:
    createRequestFn()
    createForwardFn()
    createResponseFn()
###
for fnName, fn of BasePlugin
  fn_name = "#{fnName[0].toUpperCase()}#{fnName[1..]}"
  exports["create#{fn_name}"] = fn