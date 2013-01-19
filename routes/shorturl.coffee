shorturlModel = require('../model/shorturl')

exports.shorten = (req, res) ->
  url = req.request.url
  path = req.request.route.path
  redirURI = url.split(path.split('*')?[0])?[1]
  x_ip = req?.request?.headers?['x-forwarded-for']
  unless x_ip? then x_ip = req?.request?.connection?.remoteAddress
  
  shorturlModel.shorten redirURI, 4, null, true, null,  {userIP: x_ip}, (err, shortURL) =>
    @send "short url code is http://alist.im/#{shortURL.shortURICode}"

exports.unShortenRedir = (req, res) ->
  url = req.request.url
  path = req.request.route.path
  shortCode = url.split(path.split('*')?[0])?[1]
  x_ip = req?.request?.headers?['x-forwarded-for']
  unless x_ip? then x_ip = req?.request?.connection?.remoteAddress
  console.log shortCode, url, path

  shorturlModel.retrieve shortCode, {userIP: x_ip}, (err, shortURL) =>
    if shortURL?
      #console.log "retreived short url #{shortURL}"
      @redirect shortURL.redirectURI
    else
      @next()
