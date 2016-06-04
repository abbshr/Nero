http = require 'http'

class Resolve

  defaultHeader: ->
    'X-Powered-By': 'Archangel'
    'Content-Type': 'application/json'

  forward: (url, req, callback) ->
    raw = []
    [addr, port = 80] = url.split ':'
    options =
      hostname: addr
      port: port
      path: req.etcs
      method: req.method
      header: Object.assign @defaultHeader(), req.specHeader

    client = http.request options, (res) ->
      res.on 'data', (chunk) ->
        raw.push chunk
      res.on 'end', ->
        res_data = Buffer.concat raw
        callback null, res_data.toString 'utf-8'
    
    client.on 'error', (err) ->
      raw = null
      callback err, raw

    if req.hasbody
      req.pipe client
    else
      client.end()

module.exports = Resolve