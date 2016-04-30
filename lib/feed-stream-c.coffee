net = require 'net'
{EventEmitter} = require 'events'
cbor = require 'cbor'
logger = require('./util/logger')()

class FeedStreamClient extends EventEmitter
  
  constructor: (@sock) ->
    @socket = null
    super()

  listen: (callback = ->) =>
    @ds = new cbor.Decoder()
    @socket = net.connect @sock
    @socket.on 'connect', callback
      .on 'error', @onError
      .on 'close', @onClose
    @handleDecoderEvent @socket.pipe @ds
    this

  handleDecoderEvent: (ds) ->
    ds.on 'data', @onDsData
      # .on 'end', @onDsEnd
  
  handleSocketEvent: (socket) ->
    socket.on 'error', @onError
      .on 'end', @onEnd
      .on 'error', @onError
      .on 'close', @onClose
      .on 'timeout', @onTimeout
      
  onDsData: (deltas) =>
    @emit 'data', deltas
    
  onError: (err) =>
    @emit 'error', err
    
  onClose: (err) =>
    @emit 'close', err

  close: (callback = ->) ->
    @ds?.end()
    callback()

module.exports = FeedStreamClient