# npm install -g mocha
# mocha -R nyan -w stitchTestv1.coffee --compilers coffee:coffee-script stitchTestv1.coffee


stitch = require '../model/stitch'
should = require("should")

scrts = require("./stitchTestSecrets")

describe 'stitch', =>
  generatedObjects = []
  before (done) =>
    done()
  
  after (done) =>
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
        session.sessionID.should.eql scrts.validIOIDs[0]
        generatedObjects.push session
        generatedObjects.push group
       done()
    it 'should set session displayGroupID to objectID of displayGroup', (done) ->
      stitch.on_connection scrts.validIOIDs[2], (err, session, group) ->
        session.displayGroupID.should.eql group._id.toString()
        generatedObjects.push session
        generatedObjects.push group
        done()
    it 'should permit session to be immediately findable', (done) ->
      stitch.on_connection scrts.validIOIDs[3], (err, session, group) ->
        generatedObjects.push session
        generatedObjects.push group
        stitch.Session.findOne {sessionID:scrts.validIOIDs[3]}, (err, obj) =>
          should.exist obj
          done()
    it 'should permit displaygroup to be immediately findable', (done) ->
      stitch.on_connection scrts.validIOIDs[3], (err, session, group) ->
        generatedObjects.push session
        generatedObjects.push group
        stitch.DisplayGroup.findOne {_id: group._id }, (err, obj) =>
          should.exist obj
          done()

   
  describe '#on_disconnection', =>
    before (done) =>
      stitch.on_connection scrts.validIOIDDestroyTest, (err, session, group) ->
        should.exist session, 'session should exist after setup'
        done()
    
    it 'should update others in group from the sessionID', (done) ->
      stitch.on_disconnection scrts.validIOIDDestroyTest, (socketID, data) =>
        socketID.should.not.eql socketID
  
  describe '#on_swipe', =>
    before (done) =>
      for testId in scrts.validIOIDsForAGroup
        stitch.on_connection testId, (err, session, group) ->
          should.exist session, 'session should exist after setup'
          generatedObjects.push session
          generatedObjects.push group
          done()

    it 'should emit if swipe-out is registered right after swipe-in and include emit to used swipeOut socket id', (done) ->
      stitch.on_swipe scrts.validSwipeOutForSIOID(scrts.validIOIDsForAGroup[0]),(socketID, data) ->
        should.exist socketID
        if scrts.validIOIDsForAGroup[0] == socketID
          done()

  describe '#disaffiliate', =>
    before (done) =>
      stitch.on_connection scrts.validIODisaffiliateID, (err, session, group) ->
        should.exist session, 'session should exist after setup'
        generatedObjects.push session
        generatedObjects.push group

          
    it 'if group isnt shared, should emit to affectedgroup same sessionID, amongst others or alone', (done) ->
      stitch.disaffiliate scrts.validIODisaffiliateID, (socketID, data) =>
        if socketID == scrts.validIODisaffiliateID
          done()

    it 'if group is, should emit to affectedgroup same sessionID, amongst others or alone', (done) ->
      stitch.disaffiliate scrts.validIODisaffiliateID, (socketID, data) =>
        if socketID == scrts.validIODisaffiliateID
          done()


