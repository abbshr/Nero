require './util/yaml-extend'

cluster = require 'cluster'
if cluster.isMaster
  throw new Error "Can not run in Master mode"

fs = require 'fs'
http = require 'http'
https = require 'https'
Core = require './gateway/core'
logger = require('./util/logger')()
config = require '../etc/Nero'

core = new Core config.plugin

# http server
gateway = http.createServer core.router()
gateway.listen config.gateway.port, ->
  logger.info "[worker]", "Nero server start, listen to", config.gateway.port

if config.enable_ssl
  sec_gateway = https.createServer
    key: fs.readFileSync config.key_path
    cert: fs.readFileSync config.cert_path
  , core.router()
  sec_gateway.listen config.gateway.sec_port, ->
    logger.info "[worker]", "Nero SSL enabled, listen to", config.gateway.sec_port

ipcHandle = ({cmd, data: updates}) ->
  if cmd is 'update'
    logger.verbose "[worker]", """
      worker #{process.pid} receive the updates from the master process, applying to route table...
    """
    for serviceName, settings of updates
      core.updateSettings serviceName, settings

process.on 'message', ipcHandle
process.on 'SIGINT', ->
process.on "SIGTERM", ->
  logger.warn "[worker]", "got signal: SIGTERM"
  
  gateway.close ->
    logger.warn "[worker]", 'gateway server closed'
    global.gateway_closed = yes
    unless sec_gateway? and not global.sec_gateway_closed
      process.removeListener 'message', ipcHandle
      process.exit 0
  
  sec_gateway?.close ->
    global.sec_gateway_closed = yes
    logger.warn "[worker]", 'SSL gateway server closed'
    unless global.gateway_closed
      process.removeListener 'message', ipcHandle
      process.exit 0
      