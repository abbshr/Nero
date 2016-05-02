require './lib/util/yaml-extend'

cluster = require 'cluster'
{fork} = require 'child_process'
logger = require('./lib/util/logger')()
config = require './etc/Nero'

class Master

  SIG: ["SIGTERM", "SIGINT", "SIGABRT", "SIGHUP"]

  constructor: () ->
    @agent_exec_path = "./lib/agent.coffee"
    @worker_exec_path = "./lib/worker.coffee"
    @cluster_core = config.cluster.workers
    @_closing = no
    @_agent_closed = no
    @_cluster_closed = 0
    @agent = null
    
  fork: ->
    logger.info "[master]", "process start"
    master = new Master()
    master.initSignal()
    master.initCluster()
    master.spawnWorkers()
    master.handleIPC()
    master.spawnAgent()
    
  handleIPC: ->
    process.on 'message', ({cmd, data}) ->
      if cmd is 'update'
        logger.verbose "[master]", """
          receive updates from agent, dispatching to workers...
        """
        worker.send data for _, worker of cluster.workers

  initSignal: ->
    for sig in @SIG
      logger.info "[master]", "registry signal event:", sig
      process.on sig, @signalHandle sig
          
  signalHandle: (signal) =>
    =>
      logger.warn "[master]", "got signal:", signal
      @_closing = yes
      @stopAgent "SIGTERM"
      @stopCluster "SIGTERM"
  
  spawnWorkers: (core = @cluster_core) ->
    for [1..core]
      worker = cluster.fork()

  stopCluster: (signal) ->
    worker.process.kill signal for _, worker of cluster.workers
    
  initCluster: ->
    cluster.setupMaster exec: @worker_exec_path
    cluster.on 'exit', @onWorkerExit
      .on 'disconnect', @onWorkerDisconnect
      .on 'online', @onWokerOnline

  onWorkerExit: (worker, code, signal) =>
    logger.warn "[master]", """
      worker #id=#{worker.id} exit with code [#{code}], due to signal [#{signal}]
    """
    if @_closing
      @_cluster_closed++
      if @_agent_closed and @_cluster_closed is @cluster_core
        logger.warn "[master]", "all child process exited, master exit"
        process.exit 0
    else
      logger.info "[master]", "worker respawning..."
      @spawnWorkers 1
      
  onWorkerDisconnect: (worker) =>
    logger.warn "[master]", "worker #id=#{worker.id} disconnected"

  onWokerOnline: (worker) =>
    logger.info "[master]", "worker #id=#{worker.id} start"

  spawnAgent: ->
    logger.info "[master]", "spawning agent process"
    @agent = fork @agent_exec_path
    @initAgent() 
  
  stopAgent: (signal) ->
    @agent?.kill "SIGTERM"
  
  initAgent: ->
    @agent?.on 'exit', @onAgentExit
      .on 'error', @onAgentError
      .on 'disconnect', @onAgentDisconnect
      
  uninitAgent: ->
    @agent?.removeListener 'exit', @onAgentExit
      .removeListener 'error', @onAgentError
      .removeListener 'disconnect', @onAgentDisconnect
  
  onAgentExit: (code, signal) =>
    logger.warn "[master]", """
      agent exit with code [#{code}], due to signal [#{signal}]
    """
    @uninitAgent()
    if @_closing
      @_agent_closed = yes
      if @_cluster_closed is @cluster_core
        logger.warn "[master]", "all child process exited, process exit"
        process.exit 0
    else
      logger.info "[master]", "agent respawning..."
      @spawnAgent()
  
  onAgentError: (err) => logger.error err
  
  onAgentDisconnect: => logger.warn '[master]', 'agent disconnect'

module.exports = Master