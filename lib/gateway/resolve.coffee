http = require 'http'

class Resolve

  forward: (url, req, callback) ->
    raw = []
    [addr, port = 80] = url.split ':'
    options =
      hostname: addr
      port: port
      path: req.etcs
      method: req.method
      header: req.headers
    client = http.request options, (res) ->
      res.on 'data', (chunk) ->
        raw.push chunk
      res.on 'end', ->
        res_data = Buffer.concat raw
        callback null, res_data.toString 'utf-8'
    
    client.on 'error', (err) ->
      raw = null
      callback err, raw

    req.pipe client

module.exports = Resolve