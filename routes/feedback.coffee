feedbackModel = require('../model/feedback')

exports.form = (req, res) ->
  onReq = req.query.on
  @render feedback: {feedbackOn: onReq}

exports.form_post = (req, res) ->
  x_ip = req?.request?.headers?['x-forwarded-for']
  unless x_ip? then x_ip = req?.request?.connection?.remoteAddress
  feedbackModel.addFeedback req.body.feedback, req.body.feedbackOn, {userIP: x_ip}, (err) =>
    if err?
      @send  {status: 'fail'}
    else
      @send  {status: 'success'}
