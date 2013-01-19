secrets = require ('../secrets')

mongoose = require('mongoose')
Schema = mongoose.Schema

ObjectId = mongoose.SchemaTypes.ObjectId

RedirstatSchema = new Schema {
  modifiedDate: {type: Date, index: {unique: false}}
  redirectURI: {type: String, index: {unique: true}}
  redirectCount: Number
  redirects: [{accessDate: Date, userInfo: {}}]
}

Redirstat = mongoose.model 'Redirstat', RedirstatSchema
exports.Redirstat = Redirstat
  
mongoose.connect(secrets.mongoDBConnectURLSecret)

exports.statRedirect = (redirectURI, userInfo, callback) -> #callback(err)
  if redirectURI? == true
    setInfo = {$set: {modifiedDate: new Date(), redirectURI: redirectURI}, $inc: {redirectCount: 1}, $push: {redirects:{accessDate: new Date(), userInfo: userInfo }}}
    console.log setInfo
    Redirstat.update {redirectURI: redirectURI}, setInfo , {upsert: true}, (err) ->
      if err? == true
        console.log "error updating redirStats #{err}"
      callback err
  else
    callback "no redirect uri"

exports.getRedirstatSinceDate = (date, callback) ->
  Redirstat.find {modifiedDate : {$gt: date}}, {}, (err, feedback) =>
    callback err, feedback
