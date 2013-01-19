secrets = require ('../secrets')

communicationsModel = require('./communications')

mongoose = require('mongoose')
Schema = mongoose.Schema

ObjectId = mongoose.SchemaTypes.ObjectId

FeedbackSchema = new Schema {
  modifiedDate: {type: Date, index: {unique: false}},
  feedback: {type: String},
  feedbackOn: {type: String, index: {unique: false}}
}

Feedback = mongoose.model 'Feedback', FeedbackSchema
exports.Feedback = Feedback
  
mongoose.connect(secrets.mongoDBConnectURLSecret)

exports.addFeedback = (feedback, feedbackOn, userInfo, callback) -> #callback (err)
  if feedback? == true && feedback.length > 0
   feedback = new Feedback {modifiedDate: new Date(), feedback: feedback, feedbackOn: feedbackOn, userInfo: userInfo}
   feedback.save (err) ->
    if err?
      callback "error for feedback save #{err}"
    else
      console.log "saved feedback! #{feedback}"
      communicationsModel.notifyAuthor 100000103231001, "new feedback at alist.im"
      callback null
  else
    callback "no feedback given"

exports.getFeedbackSinceDate = (date, callback) ->
  Feedback.find {modifiedDate : {$gt: date}}, {}, (err, feedback) =>
    callback err, feedback
