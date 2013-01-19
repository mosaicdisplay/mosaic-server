primaryHost = "https://stitch-server.herokuapp.com"
secrets = require ('./secrets')

shorturl = require('./routes/shorturl')
home = require('./routes/home')

stitch = require('./model/stitch.coffee')

mongoose = require('mongoose')
Schema = mongoose.Schema
ObjectId = mongoose.SchemaTypes.ObjectId

`Array.prototype.unique = function() {    var o = {}, i, l = this.length, r = [];    for(i=0; i<l;i+=1) o[this[i]] = this[i];    for(i in o) r.push(o[i]);    return r;};`

zappa = require('zappa')

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
    if @io.sockets.sockets[session.socketID]?
      return @io.sockets.sockets[session.socketID]
    else
      #console.log "session no socket #{session.socketID}"
      return null
  
  #returns whether a given session is active
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
  

  @on connection: ->
    console.log "connected id#{@id}"
    @emit connected:{status: "cool"}
  
  @on disconnect: ->
    console.log "disconnected id#{@id}"

  @on statusUpdate: ->
    tokenValidate @data.token, (user, session) =>
      if session? == false
        @emit unauthorized: {}
        return
      session.socketID = @id
      location  = @data.location
      oldLocation = session.location
      session.location = location
      #session.expiration = new Date(new Date().valueOf()+100) #no reason to expire
      #console.log session.valueOf()
      user.save (error) => #[{"location":[44.680997,10.317557],"socketID":"1998803106463826141","token":"TOKENBLAH_alex"}]
        if error?
          console.log "error saving user after StatusUpdate #{ error }"
          @emit serverError: ->
        else
          @emit updateGood: {}
          updateUniqueActiveSessionsNearLocationArray [location, oldLocation], (err) =>
            console.log "nearby update error #{err}"

  typeGroupFromMIMEInSwyp = (contentMIMEType, swyp) =>
    for type in swyp.typeGroups
      if contentMIMEType == type.contentMIME
        return type
    return null

  @on swypIn: ->
    tokenValidate @data.token, (user, session) =>
      if session? == false
        @emit unauthorized: {}
        return
      contentID   = @data.id
      contentType = @data.contentMIME
      swypForID contentID, (err, swyp) =>
        if swyp?
          typeGroupObj = typeGroupFromMIMEInSwyp contentType, swyp
          if typeGroupObj? && typeGroupObj.uploadCompletionDate?
            @emit dataAvailable:
              {id: contentID, \
              contentMIME: contentType,\
              contentURL: typeGroupObj.contentURL}
          else
            uploadURL   = "http://newUploadURL"
            @emit dataPending:
              {id: contentID, \
               type: contentType}
            @broadcast dataRequest:
              {id: contentID, \
               type: contentType,
               uploadURL: uploadURL}
     
  @on uploadCompleted: ->
    tokenValidate @data.token, (user, session) =>
      if session? == false
        @emit unauthorized: {}
        return
      contentID   = @data.id
      contentType = @data.type
      uploadURL   = "http://dbRetrievedUploadURL"
      console.log @io.sockets
      @broadcast dataAvailable:
         {id: contentID, \
         type: contentType,\
         uploadURL: uploadURL}
      #io.sockets.sockets[sid].json.send -> #send to particularly waiting clients

  #can also add client side js here
 
port = if process.env.PORT > 0 then process.env.PORT else 3000
stitchApp.app.listen port
console.log "starting on port # #{port}"
