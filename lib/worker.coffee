require './util/yaml-extend'

cluster = require 'cluster'
http = require 'http'
logger = require('./util/logger')()
# Core = require './core'
config = require '../etc/nero'

if cluster.isMaster
  throw new Error "Can not run in Master mode"

# core = new Core
# gateway = http.createServer core.router
# gateway.listen config.gateway.port, ->
#   logger.info "Nero worker start [#{process.pid}]"

ipcHandle = (updates) ->
  logger.verbose "[worker]", """
    worker #{process.pid} receive the updates from the master process, applying to route table...
  """
  for pathName, settings of updates
    core.updateRoute pathName, settings

process.on 'message', ipcHandle
process.on 'SIGINT', ->
process.on "SIGTERM", ->
  logger.warn "[worker]", "got signal: SIGTERM"
  process.exit 0