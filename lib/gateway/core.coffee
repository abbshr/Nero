connect = require 'connect'
util = require 'archangel-util'
HotConf = require './hotconf'
Resolve = require './resolve'
logger = require('../util/logger')()

class Core
  constructor: ({@request_phase, @response_phase}) ->
    # @routes = {
    #   serviceName: {
    #     _order: [pluginName, pluginName]
    #     pluginName: offset
    #     pluginName: offset
    #   }
    # }
    @app = connect()
    @service_settings = {}
    @plugins = {}
    # @order = []
    @loadPlugins()
    
  loadPlugins: ->
    @plugins['request'] = @app.stack.length
    # @order.push 'request'
    @app.use @requestFn @service_settings
    
    load_failure = []
    for pluginName in @request_phase
      try
        pluginFn = HotConf::createFn pluginName, @service_settings
        @plugins["#{pluginName}#request_phase"] = @app.stack.length
        # @order.push "#{pluginName}#request_phase"
        @app.use pluginFn
        logger.info "[gateway]", "load request phase plugin: <#{pluginName}>"
      catch err
        logger.error "[gateway]", err.message
        load_failure.push pluginName
    
    util.unorderList.rm @request_phase, pluginName for pluginName in @request_phase

    @plugins["forward"] = @app.stack.length
    # @order.push "forward"
    @app.use @forwardFn @service_settings
    
    load_failure = []
    for pluginName in @response_phase
      try
        pluginFn = HotConf::createFn pluginName, @service_settings
        @plugins["#{pluginName}#response_phase"] = @app.stack.length
        # @order.push "#{pluginName}#response_phase"
        @app.use pluginFn
        logger.info "[gateway]", "load response phase plugin: <#{pluginName}>"
      catch err
        logger.error "[gateway]", err.message
        load_failure.push pluginName

    util.unorderList.rm @response_phase, pluginName for pluginName in @response_phase
    
    @plugins["response"] = @app.stack.length
    # @order.push "response"
    @app.use @responseFn()

  router: =>
    @app

  addPlugin: (pluginName, phase, order) ->
    pluginFn = HotConf::createFn pluginName, @service_settings
    origin_offset = @plugins["#{pluginName}##{phase}"]
    forward_offset = @plugins["forward"]
    
    len = if phase is 'request'
      @request_phase.length
    else
      @response_phase.length
      
    order = Math.min order, len
    
    
    
    if origin_offset?
      if order + 1 is origin_offset
        # replace
      else
        # delete stack offset
        # 
        
    @plugins["#{pluginName}##{phase}"] = 
    @updateRoute pluginName

  delPlugin: (pluginName, phase) ->
    origin_offset = @plugins["#{pluginName}##{phase}"]

    delete @app.stack[origin_offset]
    delete @plugins["#{pluginName}##{phase}"]
    util.unorderList.rm @[phase], pluginName

    util.deflate @app.stack,
      from: origin_offset
      mutable: yes
      movedCallback: (entry, new_offset) =>
        @plugins[entry._pluginName] = new_offset

  updateSettings: (serviceName, {upstreams, plugins}) ->
    service = @service_settings[serviceName] ?= upstreams: [], plugins: {}
    service.upstreams = upstreams if upstreams
    service.plugins = plugins if plugins?
    logger.info "[gateway]", "routes table settings update successfully"

  # updateRoute: (serviceName, settings) ->
  #   route = @routes[serviceName] ? { _order: [] }
  #   forwardFn = @_proxy.bind this, serviceName
    
  #   if route._order.length > 0
  #     {_order} = route
  #     _len = _order.length
  #     delete route._order
       
  #     stack = @app.stack
  #     edge = 0
  #     for {pluginName, setting}, i in settings
  #       edge++
  #       _pluginName = _order[i]
  #       fn = HotConf.createFn pluginName, setting
  #       if _pluginName?
  #         offset = route[_pluginName]
  #         stack[offset] = route: "/#{serviceName}", handle: fn
  #         delete route[_pluginName]
  #         _order[i] = pluginName
  #       else
  #         offset = stack.length
  #         app.use serviceName, fn
  #         _order.push pluginName
  #       route[pluginName] = offset
      
  #     if edge < _len
  #       remain_rm = _order[edge..]
  #       _order = _order[...edge]
  #       fst_offset = route[remain_rm[0]]
  #       for _pluginName in remain_rm
  #         delete route[_pluginName]
  #         delete stack[route[_pluginName]]
        
  #       @app.stack = util.deflate stack, from: fst_offset, mutable: yes, (entry, new_offset) =>
  #         {route: _serviceName, handle: {_pluginName}} = entry
  #         @routes[_serviceName][_pluginName] = new_offset
            
  #     route._order = _order
  #   else
  #     offset = @app.stack.length
  #     for {pluginName, setting} in settings
  #       fn = HotConf.createFn pluginName, setting
  #       app.use serviceName, fn
  #       route[pluginName] = offset++
  #       route._order.push pluginName

  requestFn: (service_settings) =>
    (req, res, next) =>
      # 解析serviceName
      req.serviceName
      if service_settings[serviceName]?.upstreams.length
        setImmediate next
      else
        res.statusCode = 500
        res.end JSON.stringify msg: 'upstreams not found'

  forwardFn: (service_settings) =>
    (req, res, next) =>
      upstreams = service_settings[req.serviceName].upstreams
      # load balance
      i = ~~(Math.random() * upstreams.length)
      Resolve::forward upstreams[i], req, (err, upstream_res) ->
        req.upstream_res = if err?
          err.message
        else
          upstream_res
        setImmediate next, err

  responseFn: =>
    (req, res) =>
      if res.upstream_res?
        res.write JSON.stringify {upstream_res}
        res.end()
      else
        res.statusCode = 100
        res.end JSON.stringify msg: 'empty body'
  
module.exports = Core