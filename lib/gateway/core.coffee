connect = require 'connect'
util = require 'archangel-util'

HotConf = require './hotconf'
Resolve = require './resolve'

class Core
  constructor: () ->
    @app = connect()
    @routes = {}
    
    # @routes = {
    #   serviceName: {
    #     _order: [pluginName, pluginName]
    #     pluginName: offset
    #     pluginName: offset
    #   }
    # }
     
  router: (req, res, next) =>
    @app req, res, next
    
  deleteRoute: (serviceName) ->
    return unless settings = @routes[serviceName]
    
    stack = @app.stack
    delete settings._order
    
    delete stack[offset] for _, offset of settings
    
    @app.stack = util.deflate stack, movedCallback: (entry, new_offset) =>
      {route: _serviceName, {_pluginName}} = entry
      @routes[_serviceName][_pluginName] = new_offset

    delete @routes[serviceName]
  
  updateRoute: (serviceName, settings) ->
    route = @routes[serviceName] ? { _order: [] }
    forwardFn = @_proxy.bind this, serviceName
    
    if route._order.length > 0
      {_order} = route
      _len = _order.length
      delete route._order
       
      stack = @app.stack
      edge = 0
      for {pluginName, setting}, i in settings
        edge++
        _pluginName = _order[i]
        fn = HotConf.createFn pluginName, setting
        if _pluginName?
          offset = route[_pluginName]
          stack[offset] = route: "/#{serviceName}", handle: fn
          delete route[_pluginName]
          _order[i] = pluginName
        else
          offset = stack.length
          app.use serviceName, fn
          _order.push pluginName
        route[pluginName] = offset
      
      if edge < _len
        remain_rm = _order[edge..]
        _order = _order[...edge]
        fst_offset = route[remain_rm[0]]
        for _pluginName in remain_rm
          delete route[_pluginName]
          delete stack[route[_pluginName]]
        
        @app.stack = util.deflate stack, from: fst_offset, mutable: yes, (entry, new_offset) =>
          {route: _serviceName, handle: {_pluginName}} = entry
          @routes[_serviceName][_pluginName] = new_offset
            
      route._order = _order
    else
      offset = @app.stack.length
      for {pluginName, setting} in settings
        fn = HotConf.createFn pluginName, setting
        app.use serviceName, fn
        route[pluginName] = offset++
        route._order.push pluginName
            
  _proxy: (serviceName, req, res, next) ->
    Resolve.forward req, (err, upstream_res) ->
      res.head = upstream_res.head
      res.body = upstream_res.body
      res.info = upstream_res.info
      next err
  
module.exports = Core