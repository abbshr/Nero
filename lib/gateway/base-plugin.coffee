Resolve = require './resolve'
url = require 'url'
logger = require('../util/logger')()

BasePlugin =
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
      console.log service_settings[serviceName]
      if service_settings[serviceName]?.upstreams.length
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