primaryHost = "https://stitch-server.herokuapp.com"
secrets = require ('./secrets')

shorturl = require('./routes/shorturl')
home = require('./routes/home')

stitch = require('./model/stitch.coffee')

mongoose = require('mongoose')
Schema = mongoose.Schema
ObjectId = mongoose.SchemaTypes.ObjectId

`Array.prototype.unique = function() {    var o = {}, i, l = this.length, r = [];    for(i=0; i<l;i+=1) o[this[i]] = this[i];    for(i in o) r.push(o[i]);    return r;};`

swypApp = require('zappa').app ->
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

  @on connection: ->
    @emit updateRequest: {time: new Date()}
  
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

  @on swypOut: ->
    tokenValidate @data.token, (user, session) =>
      if session? == false
        @emit unauthorized: {}
        return
      #implement function to evaluate user token and abort if invalid
      supportedTypes = @data.typeGroups
      previewImage = @data.previewImagePNGBase64
      previewImageURL = @data.previewImageURL
      if (previewImageURL? == false || previewImageURL == "")
        previewImageURL = null
      recipientTo    = @data.to?.trim()
      fromSender     = {publicID: user._id, userImageURL: user.userImageURL, userName: user.userName}
      swypTime       = new Date()
      swypExpire = new Date(new Date().valueOf()+50) #expires in 50 seconds
     
      typeGroupsToSave = [] #this is for the datastore
      typeGroupsToSend = [] #this is for the swyp-out event
      if @data.typeGroups? == false || @data.typeGroups?[0]? == false
        console.log "swypOut had bad typeGroupStructure #{@data.typeGroups}"
        if previewImageURL? == true
          typeGroup = {contentURL:previewImageURL,contentMIME:"image/jpg"}
          @data.typeGroups = [typeGroup]
          console.log "new type group resolved from preview {compatibility feature!} #{typeGroup}"
        else
          @emit badData: {}
          return
      for type in @data.typeGroups
        if type?.contentMIME? == false
          console.log "bug: for some reason type.contentMIME is bad for type: ", type
          @emit badData: {}
          return
        typeGroupObj = new TypeGroup {contentMIME: type.contentMIME} #no upload or completion date or timeouts
        if type.contentURL?
          console.log "url included #{type.contentURL}"
          typeGroupObj.contentURL = type.contentURL
          typeGroupObj.uploadCompletionDate = new Date()
        typeGroupsToSave.push typeGroupObj #this gets saved
        typeGroupsToSend.push type.contentMIME #this gets emitted 

      nextSwyp = new Swyp {previewImagePNGBase64: previewImage, previewImageURL: previewImageURL, swypSender: user.userID, dateCreated: swypTime, dateExpires: swypExpire, typeGroups: typeGroupsToSave}
      nextSwyp.save (error) =>
        if error != null
          console.log "didFailSave", error
          return
        if previewImageURL? == false
          previewImageURL = "#{primaryHost}/preview/#{nextSwyp._id}"
          nextSwyp.previewImageURL = previewImageURL
          nextSwyp.save()
        swypOutPacket = {id: nextSwyp._id, swypSender: fromSender, dateCreated: nextSwyp.dateCreated, dateExpires: nextSwyp.dateExpires, availableMIMETypes: typeGroupsToSend, previewImageURL: previewImageURL}
        @emit swypOutPending: swypOutPacket #this sends only the MIMES
        console.log "new swypOut saved"
        #if no target recpient, you're swyping to area/'room'
        if recipientTo? == false || recipientTo == ""
          accountsAndSessionsNearLocation session.location, (sessionsByAccount, allSessions) =>
             if allSessions?
              for updateSession in allSessions
                socket = socketForSession(updateSession)
                if socket? && updateSession.socketID != session.socketID
                   console.log "updating swypout for sessionID #{updateSession.socketID}"
                   socket.emit('swypInAvailable', swypOutPacket)
        else
          console.log "swypOut targetted to #{recipientTo}"
          #otherwise, there is a target recipient
          accountForPublicUserID recipientTo, (error,account, activeSessions) =>
            if activeSessions?
              for updateSession in activeSessions
                socket = socketForSession(updateSession)
                if socket? && updateSession.socketID != session.socketID
                   console.log "updating swypout for sessionID #{updateSession.socketID}"
                   socket.emit('swypInAvailable', swypOutPacket)

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
  
  typeGroupFromMIMEInSwyp = (contentMIMEType, swyp) =>
    for type in swyp.typeGroups
      if contentMIMEType == type.contentMIME
        return type
    return null

  ###
  The @on swypIn event triggers from client's swypIn-action.
  The client passes its requested contentMIME, and this server either immediately emits the contentURL at which the content of contentMIME is available, or it requests the upload of said MIME to a specific URL given by this server.
  ###
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

  @coffee '/login.js': ->
    updateOrientation = ->
      orientation = 'portrait'
      switch window.orientation
        when 90 or -90 then orientation = 'landscape'
      $('body').addClass orientation

    $(->
      # handle iphone
      updateOrientation()
      window.onorientationchange = updateOrientation
      window.scrollTo(0, 1) # hide status bar on iphone
      
      $('#user_id').live 'blur', (e)->
        trimmed_mail = $(this).val().replace(/\s*/g,'').toLowerCase()
        val = CryptoJS.MD5(trimmed_mail)
        $('#avatar').attr('src',"http://gravatar.com/avatar/#{val}")

      $('#account').on 'mousedown touchstart', (e)->
        e.stopPropagation()
      $('#login_button').on 'click touchend', (e)->
        e.preventDefault()
        e.stopPropagation()
        if not $(this).hasClass 'active'
          if not $('#login').length
            $.get '/login?ajax=true', (data)->
              $content = jQuery data
              $('#account').append $content
              $('#user_id').focus()
          else
            $('#login').show()
        else
          $('#login').hide()

        $(this).toggleClass 'active'
    )

port = if process.env.PORT > 0 then process.env.PORT else 3000
swypApp.app.listen port
console.log "starting on port # #{port}"
