# npm install -g mocha
# mocha -R nyan -w stitchTestv1.coffee --compilers coffee:coffee-script stitchTestv1.coffee


stitch = require '../model/stitch'
should = require("should")

scrts = require("./stitchTestSecrets")

describe 'stitch', =>
  generatedObjects = []
  
  deleteEverything = (callback) ->
    stitch.Swyp.find().remove (err) ->
      stitch.Session.find().remove (err) ->
        stitch.DisplayGroup.find().remove (err) ->
          callback()

  errorCallback = (err) ->
    should.not.exist err

  before (done) =>
    done()
  
  after (done) =>
    console.log "deleting #{generatedObjects.length} objects"
    for toDeleteObj in generatedObjects
      toDeleteObj.remove (err) =>
        if err?
          console.log "teardown err for short #{toDeleteObj}, err: #{err}"
    done()
  
  describe '#on_connection', =>
    it 'should return a group and session and no err when passed a socketID', (done) ->
      stitch.on_connection scrts.validIOIDs[0], (err, session, group) ->
        should.exist session
        should.exist group
        should.not.exist err
        generatedObjects.push session
        generatedObjects.push group
        done()
    it 'should return err when passed pre-existing socketid', (done) ->
      stitch.on_connection scrts.validIOIDs[0], (err, session, group) ->
        should.exist err
        done()
    it 'should return err when passed no socketid', (done) ->
      stitch.on_connection null, (err, session, group) ->
        should.exist err
        done()
    it 'should return session with sessionID set to socketID', (done) ->
      stitch.on_connection scrts.validIOIDs[1], (err, session, group) ->
        session.sessionID.should.eql scrts.validIOIDs[1]
        generatedObjects.push session
        generatedObjects.push group
        done()
    it 'should set session displayGroupID to objectID of displayGroup', (done) ->
      stitch.on_connection scrts.validIOIDs[2], (err, session, group) ->
        session.displayGroupID.should.eql group._id.toString()
        generatedObjects.push session
        generatedObjects.push group
        done()
    it 'should permit session to be findable after 200ms', (done) ->
      stitch.on_connection scrts.validIOIDs[3], (err, session, group) ->
        generatedObjects.push session
        generatedObjects.push group
        setTimeout ( =>
          stitch.Session.findOne {sessionID:scrts.validIOIDs[3]}, (err, obj) =>
            should.exist obj
            done()), 200
    it 'should permit displaygroup to be findable after 200ms', (done) ->
      stitch.on_connection scrts.validIOIDs[3], (err, session, group) ->
        generatedObjects.push session
        generatedObjects.push group
        setTimeout ( =>
          stitch.DisplayGroup.findOne {_id: group._id }, (err, obj) =>
            should.exist obj
            done()), 200
  
  describe '#on_disconnection', =>
    before (done) =>
      stitch.on_connection scrts.validIOIDDestroyTest, (err, session, group) ->
        should.exist session, 'session should exist after setup'
        done()
     

    it.skip 'should update others in group from the sessionID', (done) ->
      stitch.on_disconnection scrts.validIOIDDestroyTest, ((socketID, data) =>
        socketID.should.not.eql socketID
        done()
        ), (error) =>
          should.not.exist error
          if error?
            console.log "error callback on disconnection #{error}"
  
  describe '#on_swipe', =>
    beforeEach (done) =>
      deleteEverything ->
        for i in [0..scrts.validIOIDsForAGroup.length - 1]
          do (i) =>
            testId = scrts.validIOIDsForAGroup[i]
            stitch.on_connection testId, (err, session, group) =>
              should.exist session, 'session should exist after setup'
              generatedObjects.push session
              generatedObjects.push group
              if i == scrts.validIOIDsForAGroup.length - 1
                done()
    it 'shouldnt emit anything on first swipe-in if no swipe-out occured, but should do callback with null params', (done) ->
      stitch.on_swipe scrts.validIOIDsForAGroup[0], scrts.validSwipeInForSIOID(scrts.validIOIDsForAGroup[0]),((session, data) =>
        assert(false)), (err) ->
          setTimeout (->
            done()
          ), 1000

    it 'should emit if swipe-out is registered right after swipe-in and include emit to used swipeOut socket id', (done) ->
      stitch.on_swipe scrts.validIOIDsForAGroup[0], scrts.validSwipeInForSIOID(scrts.validIOIDsForAGroup[0]),((session0, data) =>
        assert(false)), (err) ->
          stitch.on_swipe scrts.validIOIDsForAGroup[1], scrts.validSwipeOutForSIOID(scrts.validIOIDsForAGroup[1]),((session1, data) ->
            console.log "emitting data to socket: #{session1} // should be #{scrts.validIOIDsForAGroup[0]}, data: #{data}"
            should.exist session1
            if scrts.validIOIDsForAGroup[1] == session1.sessionID
              console.log 
              done()), errorCallback
     
    it 'should emit at least 3 times if swipe-out is registered then swipe-in between devices 1 and 2', (done) ->
      sessionIDs = []
      stitch.on_swipe scrts.validIOIDsForAGroup[0], scrts.validSwipeOutForSIOID(scrts.validIOIDsForAGroup[0]),((session0, data) =>
        assert(false)), (err) ->
          stitch.on_swipe scrts.validIOIDsForAGroup[1], scrts.validSwipeInForSIOID(scrts.validIOIDsForAGroup[1]),((session1, data) ->), (err) ->
            stitch.on_swipe scrts.validIOIDsForAGroup[1], scrts.validSwipeOutForSIOID(scrts.validIOIDsForAGroup[1]),((session1_2, data) =>
              assert(false)), (err) ->
                stitch.on_swipe scrts.validIOIDsForAGroup[2], scrts.validSwipeInForSIOID(scrts.validIOIDsForAGroup[2]),((session, data) ->
                  sessionIDs.push(session.sessionID)
                  if(sessionIDs.length == 3)
                    done()
                  ), (err) ->
  
    it 'should deafiliate (have different displayGroupIDs), and emit three times if swipe out occurs from device 2 to device 1', (done) ->
      sessionIDs = []
      stitch.on_swipe scrts.validIOIDsForAGroup[0], scrts.validSwipeOutForSIOID(scrts.validIOIDsForAGroup[0]),((session0, data) => assert(false)), (err) ->
          stitch.on_swipe scrts.validIOIDsForAGroup[1], scrts.validSwipeInForSIOID(scrts.validIOIDsForAGroup[1]),((session1, data) ->), (err) ->
            stitch.on_swipe scrts.validIOIDsForAGroup[1], scrts.validSwipeOutForSIOID(scrts.validIOIDsForAGroup[1]),((session1_2, data) => assert(false)), (err) ->
                stitch.on_swipe scrts.validIOIDsForAGroup[2], scrts.validSwipeInForSIOID(scrts.validIOIDsForAGroup[2]),((session, data) ->), (err) ->
                  stitch.on_swipe scrts.validIOIDsForAGroup[2], scrts.validSwipeOutForSIOID(scrts.validIOIDsForAGroup[2]),((session1_2, data) => assert(false)), (err) ->
                      stitch.on_swipe scrts.validIOIDsForAGroup[1], scrts.validSwipeInForSIOID(scrts.validIOIDsForAGroup[1]),((session, data) ->
                        sessionIDs.push(session.sessionID)
                        console.log 'at this point sessionids is '+ JSON.stringify sessionIDs
                        if(sessionIDs.length == 3)
                          done()
                        ), (err) ->

  
  describe '#disaffiliate', =>
    before (done) =>
      stitch.on_connection scrts.validIODisaffiliateID, (err, session, group) ->
        should.exist session, 'session should exist after setup'
        generatedObjects.push session
        generatedObjects.push group
        done()

    it 'if group isnt shared should emit only to new group', (done) ->
      stitch.disafilliate scrts.validIODisaffiliateID, ((session, data) =>
        console.log "X: socketID: #{session.sessionID} data: #{data}"
        if session.sessionID == scrts.validIODisaffiliateID
          done()), errorCallback

    it 'if group is shared, should emit to old and new group', (done) ->
      stitch.disafilliate scrts.validIODisaffiliateID, ((session, data) =>
        console.log "Y: socketID: #{session.sessionID} data: #{data}"
        if session.sessionID == scrts.validIODisaffiliateID
          done()), errorCallback


