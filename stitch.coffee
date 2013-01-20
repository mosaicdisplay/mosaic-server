primaryHost = "https://stitch-server.herokuapp.com"
secrets = require ('./secrets')

shorturl = require('./routes/shorturl')
home = require('./routes/home')

stitch = require('./model/stitch')

mongoose = require('mongoose')
Schema = mongoose.Schema
ObjectId = mongoose.SchemaTypes.ObjectId

`Array.prototype.unique = function() {    var o = {}, i, l = this.length, r = [];    for(i=0; i<l;i+=1) o[this[i]] = this[i];    for(i in o) r.push(o[i]);    return r;};`

zappa = require('zappa')

sampleURL = "http://upload.wikimedia.org/wikipedia/commons/8/8c/K2%2C_Mount_Godwin_Austen%2C_Chogori%2C_Savage_Mountain.jpg"
sampleContentSize = {width: 3008, height: 2000}

stitchApp = zappa.app ->
  @use 'bodyParser', 'static', 'cookies', 'cookieParser', session: {secret: secrets.sessionSecret}
  #@use  mongooseAuth.middleware()
  #mongooseAuth.helpExpress @app
  
  crypto = require('crypto')
  
  #force longpolling
  @io.set("transports", ["xhr-polling"])
  @io.set("polling duration", 10)
 
  @get '*': ->
    if @request.headers['host'] == '127.0.0.1:3000'
      @next()
    else if @request.headers['x-forwarded-proto']!='https'
      @redirect "#{primaryHost}#{@request.url}"
    else
      @next()

  @get '/', home.home

  socketForSession = (session) =>
    return socketForSocketID(session?.socketID)
  
  socketForSocketID = (socketID) =>
    if @io.sockets.sockets[socketID]?
      return @io.sockets.sockets[socketID]
    else
      return null
  
  sessionIsActive = (session) =>
    if (socketForSession(session)?)
      return true
    else
      #console.log "not active #{socketForSession(session)}"
      return false

  swypForID = (id, callback) => #{callback(err, swypObj)}
    if id? == false
       callback "noID", null
       return
    try
      objID = mongoose.mongo.BSONPure.ObjectID.fromString(id)
    catch err
      console.log "objID err: #{err} from id #{id}"
    Swyp.findOne {_id: objID}, (err, obj) =>
      if err? or (obj? == false)
         console.log "no swyp for id #{id} found, w. err #{err}"
         callback err, null
         return
      if obj?
        callback null, obj
  

  #client2server
  @on connection: ->
    console.log "connected id#{@id}"
    stitch.on_connection @id, (err) ->
      console.log "on_connection err #{err}"
    #create session
    #create display group
    #adding new session, and creating new displayGroup
  
  @on disconnect: ->
    stitch.on_disconnection @id, ((session, data) ->
      socketForSocketID(session.sessionID).emit {updateDisplay: data}), (err) ->
        console.log "on_disconnection err #{err}"

  @on swypOccurred: ->
    stitch.on_swipe @id, @data, ((session, data) ->
      socketForSocketID(session.sessionID).emit {updateDisplay: data}), (err) ->
        if err?
          console.log "error at swyp occured #{err}"

    console.log "swyp occurred with id #{@id}, data: #{@data}"

  @on disaffiliate: ->
    stitch.disaffiliate @id, ((session, data) ->
      socketForSocketID(session.sessionID).emit {updateDisplay: data}), (err) ->
        if err?
          console.log "error at disafiliate occured #{err}"

  @on setContent: ->
    stitch.setContent @id, @data, ((session, data) ->
      socketForSocketID(session.sessionID).emit {updateDisplay: data}), (err) ->
        if err?
          console.log "error at setContent occured #{err}"

  # emitSampleToSocketID = (socketID, callback) =>
  #   socketForSocketID(socketID).emit updateDisplay: {url: sampleURL, boundarySize: {width: 1500, height: 997}, screenSize: {width: 320, height: 548}, origin: {x:320, y:200}}

  @client '/swyp.js': ->
    @connect()
    

port = if process.env.PORT > 0 then process.env.PORT else 3000
stitchApp.app.listen port
console.log "starting on port # #{port}"
