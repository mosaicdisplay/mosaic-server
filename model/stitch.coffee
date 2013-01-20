secrets = require("../secrets")
crypto = require("crypto")
mongoose = require("mongoose")
_ = require('./underscore-min')


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
  session.origin = {x: 0, y: 0}
  session.physicalSize = {width: 0, height: 0}
  group.contentURL = "http://i.imgur.com/Us4J3C4.jpg"
  group.save (err) =>
    session.save (err) =>
      callback err, session, group

#needs to both 1) update displayGroup boundary size
#   2) update each associated session with a rect based on content display
updateDisplayGroupsOfIDs = (displayGroupIDs, emitter, callback) -> #callback (err) #emitter(session, socketData)
  #console.log "need to update each of #{displayGroupIDs}"
  for groupID in displayGroupIDs
    do (groupID) ->
      DisplayGroup.findOne {_id: makeObjectID(groupID)}, (err, group) =>
        if group? == false
          callback "no group found for groupID: #{groupID}"
          return

        Session.find {displayGroupID: groupID}, (err, sessions) =>
          if sessions.length == 0
            return

          minX = _.min(_.map(sessions, (session) -> session.origin.x))
          minY = _.min(_.map(sessions, (session) -> session.origin.y))

          console.log "updateDisplayGroupsOfIDs: minx and miny are #{minX} #{minY}"

          for session in sessions
            session.origin.x -= minX
            session.origin.y -= minY
            session.save()

          maxX = _.max(_.map(sessions, (session) -> session.origin.x + session.physicalSize.width))
          maxY = _.max(_.map(sessions, (session) -> session.origin.y + session.physicalSize.height))

          group.boundarySize.width = maxX
          group.boundarySize.height = maxY
          group.save()

          for session in sessions
            emitData = {
              url: group.contentURL,
              boundarySize: group.boundarySize,
              screenSize: session.physicalSize,
              origin: session.origin
            }
            
            console.log "updated id #{session.sessionID} with emit data #{emitData}"
            
            emitter session, emitData
  callback null

#disconnects and cascades changes
exports.disafilliate = (socketID, emitter, callback) ->
  Session.findOne {sessionID: socketID}, (err, sessionObj) ->
    newDG = new DisplayGroup {contentURL: 'http://i.imgur.com/Us4J3C4.jpg'}
    oldDisplayGroupID = sessionObj.displayGroupID
    newDisplayGroupID = newDG._id.toString()
    console.log "disafilliateing session with group #{oldDisplayGroupID } to id #{newDisplayGroupID}"
    sessionObj.displayGroupID = newDisplayGroupID
    newDG.save (err) ->
      if err?
        console.log "non-critical group-save err #{err}"
      sessionObj.save (err) ->
        updateDisplayGroupsOfIDs [oldDisplayGroupID, newDisplayGroupID], emitter, callback
      

#now passes session in emitter
#callback fires after delete happens
exports.on_disconnection = (socketID, emitter, callback) -> #emitter(session, socketData) #callback(err)
  Session.findOne {sessionID: socketID}, (err, sessionObj) =>
    exports.disafilliate socketID, emitter, (err) =>
      #race condition with disafiliate's updateDisplayGroupsOfIDs call-- maybe makes sense just to leave hanging...
      sessionObj.remove (err) =>
        callback err

#we need to add a new swipe object, then check for partner one
#if partner one, we need to connect them via a shared displayGroup and call updateDisplayGroupsOfIDs
exports.on_swipe = (socketID, swipeData, emitter, callback) -> #callback (err)
  if swipeData? == false
    callback "no data"
    return

  Session.findOne {sessionID: socketID}, (err, session) ->
    session.physicalSize = swipeData.screenSize
    session.save()

  swyp = new Swyp {sessionID: socketID, dateCreated: new Date(), swypPoint: swipeData?.swypPoint , screenSize: swipeData?.screenSize, direction: swipeData.direction}
  swyp.save (err) =>
    floorDate = new Date(swyp.dateCreated.valueOf()-2500)
    searchDir = if swyp.direction == 'out' then 'in' else 'out'
    Swyp.findOne {dateCreated: {$gt: floorDate}, direction: searchDir}, (err, matchSwyp) ->
      if matchSwyp? == false
        #nothing to do here, wait for pair
        callback()
        return
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
     
      #if the same, we disaffiliate the master -- the inverse
      if masterSession.displayGroupID == receivingSession.displayGroupID
        console.log "disaffiliating #{masterSession.sessionID} and #{receivingSession.sessionID}"
        exports.disafilliate masterSession.sessionID, emitter, callback
      else #if different, we inherit the master's session
        console.log "affiliating #{masterSession.sessionID} and #{receivingSession.sessionID}"
        receivingSession.displayGroupID = masterSession.displayGroupID


        console.log 'absoluteSwypX = #{masterSession.origin.x} + #{outSwyp.swypPoint.x}'
        console.log 'receivingSession.origin.x = #{absoluteSwypX} - #{inSwyp.swypPoint.x}'

        absoluteSwypX = masterSession.origin.x + outSwyp.swypPoint.x
        receivingSession.origin.x = absoluteSwypX - inSwyp.swypPoint.x

        console.log 'absoluteSwypY = #{masterSession.origin.y} + #{outSwyp.swypPoint.y}'
        console.log 'receivingSession.origin.y = #{absoluteSwypY} - #{inSwyp.swypPoint.y}'

        absoluteSwypY = masterSession.origin.y + outSwyp.swypPoint.y
        receivingSession.origin.y = absoluteSwypY - inSwyp.swypPoint.y

        console.log "receivingSession origin is #{JSON.stringify receivingSession.origin}"

        receivingSession.save (err) =>
          updateDisplayGroupsOfIDs [masterSession.displayGroupID], emitter, callback

      inSwyp.remove()
      outSwyp.remove()
