Resolve = require './resolve'
url = require 'url'
logger = require('../util/logger')()

BasePlugin =
  requestFn: (service_settings) ->
    (req, res, next) ->
      # 解析serviceName
      {pathname} = url.parse req.url
      serviceName = req.serviceName = pathname.split('/')[1]
      req.cfg = {}
      logger.debug "[base plugin - requestFn]", "got serviceName", serviceName
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
      Resolve::forward upstreams[i], req, (err, upstream_res) ->
        req.upstream_res = if err?
          err.message
        else
          upstream_res
        next()

  responseFn: ->
    (req, res) ->
      if res.upstream_res?
        res.write JSON.stringify {upstream_res}
        res.end()
      else
        res.statusCode = 200
        res.end JSON.stringify msg: 'empty body'

for fnName, fn of BasePlugin
  fn_name = "#{fnName[0].toUpperCase()}#{fnName[1..]}"
  exports["create#{fn_name}"] = fn