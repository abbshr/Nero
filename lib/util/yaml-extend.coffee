# setup yaml complier
{safeLoad} = require 'js-yaml'
{readFileSync} = require 'fs'
require.extensions['.yaml'] ?= (module, filename) ->
  try
    module.exports = safeLoad readFileSync filename
  catch err
    err.message = "#{filename}: #{err.message}"
    throw err

# setup cson parser
{load} = require 'cson'
require.extensions['.cson'] ?= (module, filename) ->
  try
    module.exports = load filename
  catch
    err.message = "#{filename}: #{err.message}"
    throw err