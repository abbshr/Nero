http = require 'http'

class Resolve

  forward: (url, req, callback) ->
    raw = []
    client = http.connect url, ->
      req.pipe client
    client.on 'data', (chunk) ->
      raw.push chunk
    client.on 'error', (err) ->
      raw = null
      callback err, raw
    client.on 'end', ->
      res_data = Buffer.concat raw
      callback null, res_data.toString 'utf-8'

module.exports = Resolve