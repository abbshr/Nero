require './util/yaml-extend'

logger = require('./util/logger')()
FeedStreamClient = require './feed-stream-c'
config = require '../etc/Nero'

replica_services = {}
replica_plugins = {}

logger.info "[agent]", "process start"
feed_stream = new FeedStreamClient config.feed_stream.sock

feed_stream.listen ->
  logger.info "[agent]", "feed stream connected"
.on 'data', (deltas) ->
  # [[k,v,n],...]
  for [k, v, n] in deltas
    [serviceName, pluginName] = k.split "#"
    replica_services[serviceName] ?= {}

    if pluginName?
      logger.info "[agent]", "update plugin config:", k
      replica_plugins[serviceName] ?= {}
      replica_plugins[serviceName][pluginName] = v
    else
      logger.info "[agent]", "update service:", k
      replica_services[serviceName] = v
  
  for serviceName, plugins of replica_plugins
    replica_services[serviceName].plugins = plugins

notifyMaster = ->
  setTimeout ->
    updates = cmd: 'updates', data: replica_services
    process.send updates, (err) ->
      logger.verbose "[agent]", "send updates to master process"
      notifyMaster()
    updates = null
    global.replica_services = {}
  , config.agent.push_val

process.on 'SIGINT', ->
process.on "SIGTERM", ->
  logger.warn "[agent]", "got signal: SIGTERM"
  feed_stream.close ->
    logger.warn "[agent]", "disconnected feed stream"
    logger.warn "[agent]", "process exit"
    process.exit 0