require './util/yaml-extend'

cluster = require 'cluster'
if cluster.isMaster
  throw new Error "Can not run in Master mode"

http = require 'http'
Core = require './gateway/core'
logger = require('./util/logger')()
config = require '../etc/Nero'

core = new Core config.plugin
gateway = http.createServer core.router()
gateway.listen config.gateway.port, ->
  logger.info "[worker]", "Nero worker start [#{process.pid}], listen to", config.gateway.port

ipcHandle = (updates) ->
  logger.verbose "[worker]", """
    worker #{process.pid} receive the updates from the master process, applying to route table...
  """
  for serviceName, settings of updates
    core.updateRoute serviceName, settings

process.on 'message', ipcHandle
process.on 'SIGINT', ->
process.on "SIGTERM", ->
  logger.warn "[worker]", "got signal: SIGTERM"
  gateway.close ->
    logger.warn "[worker]", 'gateway server closed'
    process.removeListener 'message', ipcHandle
    process.exit 0