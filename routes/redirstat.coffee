redirstatModel = require('../model/redirstat')

exports.form = (req, res) ->
  onReq = req.query.on
  @render feedback: {feedbackOn: onReq}

exports.redir = (req, res) ->
  url = req.request.url
  path = req.request.route.path
  redirURI = url.split(path.split('*')?[0])?[1]
  x_ip = req?.request?.headers?['x-forwarded-for']
  unless x_ip? then x_ip = req?.request?.connection?.remoteAddress
  
  @redirect redirURI
  redirstatModel.statRedirect redirURI, {userIP: x_ip}, (err) =>
    console.log "logged redir to #{redirURI} w/ err #{err}"
