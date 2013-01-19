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
    it 'should return session with sessionID set to socketID', (done) ->
      stitch.on_connection scrts.validIOIDs[0], (err, session, group) ->
        session.sessionID.should.eql scrts.validIOIDs[0]
    it 'should set session displayGroupID to objectID of displayGroup', (done) ->
      stitch.on_connection scrts.validIOIDs[0], (err, session, group) ->
        session.displayGroupID.should.eql group._id.toString()
    it 'should return err when passed no socketID', (done) ->
      stitch.on_connection null, (err, session, group) ->
        should.exist err

###
    it 'should shorten unique (not in db) urls with unique short code', (done) ->
      stitch.shorten scrts.validTestRedirectURI, scrts.codeLength, null, false, null, null, (err, shortURL) =>
        generatedShortened.push shortURL
        should.not.exist err
        shortURL.redirectURI.should.eql scrts.validTestRedirectURI
        should.exist shortURL.shortURICode
        done()

  describe '#retrieve', =>
    it 'should properly reset last access date after retreiving', (done) ->
      stitch.retrieve scrts.validCodeRedirectPairs[0][0], scrts.validUserInfo, (err, shortURL) =>
        should.not.exist err
        Math.abs((shortURL.modifiedDate.getTime()- new Date().getTime())).should.be.below(1000)
        done()
###
