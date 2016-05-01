connect = require 'connect'
util = require 'archangel-util'
HotConf = require './hotconf'
BasePlugin = require './base-plugin'
logger = require('../util/logger')()

class Core
  constructor: ({request_phase = [], response_phase = []}) ->
    @app = connect()
    @service_settings = {}
    @request_phase_len = 0
    @response_phase_len = 0
    @request_phase = {}
    @response_phase = {}
    @loadPlugins request_phase, response_phase

  router: =>
    @app

  loadPlugins: (request_phase, response_phase) ->
    @app.use BasePlugin.createRequestFn @service_settings

    for pluginName in request_phase
      try
        pluginFn = HotConf::createFn pluginName, @service_settings
      catch err
        logger.error "[gateway]", err.message
        continue

      @request_phase[pluginName] = @app.stack.length
      @app.use pluginFn
      @request_phase_len++
      logger.info "[gateway]", "load request phase plugin: <#{pluginName}>"

    @app.use BasePlugin.createForwardFn @service_settings

    for pluginName in response_phase
      try
        pluginFn = HotConf::createFn pluginName, @service_settings
      catch err
        logger.error "[gateway]", err.message
        continue
      
      @response_phase[pluginName] = @app.stack.length
      @app.use pluginFn
      @response_phase_len++
      logger.info "[gateway]", "load response phase plugin: <#{pluginName}>"

    @app.use BasePlugin.createResponseFn()

  enablePlugin: (pluginName, phase, order) ->
    try
      pluginFn = HotConf::createFn pluginName, @service_settings
    catch err
      logger.error "[gateway]", err.message
      return no

    plugin_s = @[phase]
    unless plugin_s?
      logger.error "[gateway]", "only request_phase and response_phase permitted"
      return no

    stack = @app.stack
    entry = route: '', handle: pluginFn
    if pluginName of plugin_s
      order = Math.min order, @["#{phase}_len"] - 1
      origin_order = plugin_s[pluginName]
      if not order? or order is origin_order
        stack[origin_order].handle = pluginFn
      else
        st = if order > origin_order then 1 else -1
        for i in [origin_order...order]
          stack[i] = stack[i + st]
          _plugin_name = stack[i + st].handle.pluginName
          plugin_s[_plugin_name] = i + st
        stack[order] = entry
        plugin_s[pluginName] = order
      logger.info "[gateway]", "update plugin <#{pluginName}> in #{phase}"
    else
      order = Math.min order, @["#{phase}_len"]
      stack.splice order, 0, entry
      plugin_s[pluginName] = order
      @["#{phase}_len"]++
      for i in [order...stack.length]
        _plugin_name = stack[i + 1].handle.pluginName
        plugin_s[_plugin_name] = i + 1 if plugin_s[_plugin_name]?
      logger.info "[gateway]", "enable plugin <#{pluginName}> in #{phase}"
  
  disablePlugin: (pluginName, phase) ->
    stack = @app.stack
    plugin_s = @[phase]
    unless plugin_s?
      logger.error "[gateway]", "only request_phase and response_phase permitted"
      return no

    order = plugin_s[pluginName]
    if order?
      stack[order]?.handle.enabled = no
      # delete plugin_s[pluginName]
      # delete stack[order]
      # @app.stack = util.orderList.deflate stack,
      #   from: order
      #   mutable: yes
      #   movedCallback: ({handle: {pluginName}}, new_order) ->
      #     plugin_s[pluginName] = new_order if plugin_s[pluginName]?
      logger.info "[gateway]", "disable plugin #{pluginName} in #{phase}"

  updateSettings: (serviceName, {upstreams, plugins}) ->
    service = @service_settings[serviceName] ?= upstreams: [], plugins: {}
    service.upstreams = upstreams if upstreams
    service.plugins = plugins if plugins?
    logger.info "[gateway]", "routes table settings update successfully"
      
module.exports = Core