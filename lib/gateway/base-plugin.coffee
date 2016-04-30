Resolve = require './resolve'

BasePlugin =
  requestFn: (service_settings) ->
    (req, res, next) ->
      # 解析serviceName
      req.serviceName
      if service_settings[serviceName]?.upstreams.length
        setImmediate next
      else
        res.statusCode = 500
        res.end JSON.stringify msg: 'upstreams not found'

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
        setImmediate next, err

  responseFn: ->
    (req, res) ->
      if res.upstream_res?
        res.write JSON.stringify {upstream_res}
        res.end()
      else
        res.statusCode = 100
        res.end JSON.stringify msg: 'empty body'

for fnName, fn of BasePlugin
  fn_name = "#{fnName[0].toUpperCase()}#{fnName[1..]}"
  exports["create#{fn_name}"] = fn