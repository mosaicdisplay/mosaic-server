secrets = require ('../secrets')

##zain  -- you can use js w.o. putting js extension here...
#computeRect = require('./computeRect')

crypto = require('crypto')
mongoose = require('mongoose')
Schema = mongoose.Schema

ObjectId = mongoose.SchemaTypes.ObjectId

SessionSchema = new Schema {
  sessionID : { type: String, required: true, index: { unique: true }}
  displayGroupID: {type: String, required: true, index: {unique: false}}
  physicalSize: {width: Number, height: Number}
  origin: {x:Number, y:Number}
}


DisplayGroupSchema = new Schema {
  boundarySize: {width: Number, height: Number}
  contentURL: String
  contentSize: {width: Number, height: Number}
}


SwypSchema = new Schema {
  sessionID : String
  dateCreated : Date
  swypPoint: {x:Number, y:Number} #from bottom left
  direction: String #"in" or "out"
}

Session = mongoose.model 'Sessions', SessionSchema
Swyp = mongoose.model 'Swyp', SwypSchema
DisplayGroup = mongoose.model 'DisplayGroup', DisplayGroupSchema

mongoose.connect(secrets.mongoDBConnectURLSecret)

exports.initializeConnection = (socketID, callback) -> #callback(err, Session<object>)
  if socketID? == false
    callback 'no socketid included'
    return
