secrets = require("../secrets")
crypto = require("crypto")
mongoose = require("mongoose")

Schema = mongoose.Schema
makeObjectID = mongoose.mongo.BSONPure.ObjectID.fromString
exports.makeObjectID = makeObjectID

SessionSchema = new Schema(
  sessionID:
    type: String
    required: true
    index:
      unique: true

  displayGroupID:
    type: String
    required: true
    index:
      unique: false

  physicalSize:
    width: Number
    height: Number

  origin:
    x: Number
    y: Number
)
DisplaySchema = new Schema(
  boundarySize:
    width: Number
    height: Number

  contentURL: String
)
SwypSchema = new Schema(
  sessionID: String
  dateCreated: Date
  swypPoint:
    x: Number
    y: Number

  direction: String
)

Session = mongoose.model("Sessions", SessionSchema)
exports.Session = Session

Swyp = mongoose.model("Swyp", SwypSchema)
exports.Swyp = Swyp

DisplayGroup = mongoose.model("Display", DisplaySchema)
exports.DisplayGroup = DisplayGroup

mongoose.connect secrets.mongoDBConnectURLSecret

exports.on_connection = (socketID, callback) -> #callback(err, session, group)
  group = new DisplayGroup()
  session = new Session()
  session.displayGroupID = group._id.toString()
  session.sessionID = socketID
  group.contentURL = "http://i.imgur.com/Us4J3C4.jpg"
  group.save (err) =>
    session.save (err) =>
      callback err, session, group

#needs to both 1) update displayGroup boundary size
#   2) update each associated session with a rect based on content display
updateDisplayGroupsOfIDs = (displayGroupIDs, emitter, callback) -> #callback (err) #emitter(session, socketData)
  console.log "need to update each of #{displayGroupIDs}"
  for groupID in displayGroupIDs
    DisplayGroup.findOne {_id: makeObjectID(groupID)}, (err, group) =>
      Session.find {displayGroupID: groupID}, (err, sessions) =>
        for session in sessions
          
          #replace me!
          boundarySize = {width: sessions.length * 320, height: sessions.length * 548}
          screenSize = {width: 320, height: 548}
          
          emitData = {url: group.contentURL, boundarySize: boundarySize, screenSize: screenSize, origin: {x: screenSize.width * (sessions.length -1), y: screenSize.height * (sessions.length -1)}}
          console.log "updated id #{session.sessionID} with emit data #{emitData}"

          emitter session, emitData
  callback null

#disconnects and cascades changes
exports.disafilliate = (socketID, emitter, callback) ->
  Session.findOne {sessionID: socketID}, (err, sessionObj) ->
    newDG = new DisplayGroup {}
    oldDisplayGroupID = sessionObj.displayGroupID
    newDisplayGroupID = newDG._id.toString()
    console.log "disafilliateing session with group #{oldDisplayGroupID } to id #{newDisplayGroupID}"
    sessionObj.displayGroupID = newDisplayGroupID
    sessionObj.save (err) ->
      updateDisplayGroupsOfIDs [oldDisplayGroupID, newDisplayGroupID], emitter, callback
      

#now passes session in emitter
#callback fires after delete happens
exports.on_disconnection = (socketID, emitter, callback) -> #emitter(session, socketData) #callback(err)
  Session.findOne {sessionID: socketID}, (err, sessionObj) ->
    exports.disafilliate socketID, emitter, (err) ->
      #race condition with disafiliate's updateDisplayGroupsOfIDs call-- maybe makes sense just to leave hanging...
      sessionObj.delete (err) ->
        callback err

#we need to add a new swipe object, then check for partner one
#if partner one, we need to connect them via a shared displayGroup and call updateDisplayGroupsOfIDs
exports.on_swipe = (socketID, swipeData, emitter, callback) -> #callback (err)
  if swipeData? == false
    callback "no data"
    return
  swyp = new Swyp {sessionID: socketID, dateCreated: new Date(), swypPoint: swipeData?.swypPoint , screenSize: swipeData?.screenSize, direction: swipeData.direction}
  swyp.save (err) =>
    floorDate = new Date(swyp.dataCreated.valueOf()-1000)
    searchDir = (swyp.direction == "out")? "in" : "out"
    Swyp.findOne {dataCreated: {$gt: floorDate}, direction: searchDir}, (err, matchSwyp) ->
      console.log "found partner: #{matchSwyp}"
      if swyp.direction == "in"
        pairSwyps swyp, matchSwyp, emitter, callback
      else
        pairSwyps matchSwyp, swyp, emitter, callback

pairSwyps = (inSwyp, outSwyp, emitter, callback) -> #callback(err)
  Session.findOne {sessionID: outSwyp.sessionID}, (err, masterSession) ->
    if masterSession? == false
      callback "missing session of id #{outSwyp.sessionID}"
      return
    Session.findOne {sessionID: inSwyp.sessionID}, (err, receivingSession) ->
      if receivingSession? == false
        callback "missing session of id #{inSwyp.sessionID}"
        return
     
      inSwyp.delete()
      outSwyp.delete()
 
      #if the same, we disaffiliate the master -- the inverse
      if masterSession.displayGroupID == receivingSession.displayGroupID
        exports.disafilliate masterSession.sessionID, emitter, callback
      else #if different, we inherit the master's session
        receivingSession.displayGroupID = masterSession.displayGroupID
        receivingSession.save (err) =>
          updateDisplayGroupsOfIDs [masterSession.displayGroupID], emitter, callback
