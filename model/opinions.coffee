
fs = require 'fs'

opinionList = null

exports.opinions = (callback) -> #callback(err, opinionArray)
  if opinionList? == false
    fs.readFile './model/opinions.md', 'utf8', (err, str) ->
      if str?
        opinionList = str.split('\n\n')
        console.log 'loaded opinions'
      else
        console.log err
      callback null, opinionList
  else
    callback null, opinionList
  
