primaryHost = "https://swypserver.herokuapp.com"
#if process.env.NODE_ENV? == false || process.env.NODE_ENV != "PRODUCTION"
#primaryHost = "http://127.0.0.1:3000"
secrets = require ('./secrets')

mongoose     = require('mongoose')
mongooseAuth = require('mongoose-auth')
Schema = mongoose.Schema

ObjectId = mongoose.SchemaTypes.ObjectId

#sessions are contained within accounts, and represent an active connection to the swypServer
#sessions contain the socket.io socket id via 'socketID', and the current location of the user
SessionSchema = new Schema {
  token : String,
  socketID : String,
  expiration : Date,
  location : [ Number, Number] #long,lat as suggested: http://www.mongodb.org/display/DOCS/Geospatial+Indexing 
}

#the account schema contains the user information and login credentials
#the userIDs are unique, and can be universal identifiers (more internal than userName)
#the userName is the display name for other users to see
#the account document contains the session embeddedDocument 
Account = null
AccountSchema = new Schema {
  userImageURL : String,
  userID : { type: String, required: true, index: { unique: true }},
  userName : { type: String, required: true},
  userPass : String
  sessions : [SessionSchema]
}

'''
AccountSchema.plugin mongooseAuth, {
  everymodule: {everyauth: User: -> Account}
  facebook:
    everyauth:
      myHostname: primaryHost
      appId: secrets.fb.id
      appSecret: secrets.fb.secret
      redirectPath: '/'
}
'''

#each contentType the swyp-out supports generates one of these
#typeGroups are fufilled as necessary to honor requests through swyp-ins
TypeGroupSchema = new Schema {
  contentURL : String
  contentMIME : String
  requestingUserIDs : [String]
  uploadTimeoutDate : Date
  uploadCompletionDate : Date
}

# each swyp-out generates one of these
# it contains typeGroups, which are the various contentTypes supported by a specific swyped-out content
# swypSenderID corresponds to a unique Account.userID
SwypSchema = new Schema {
  swypSenderID : String,
  swypRecipientID : String,
  dateCreated : Date,
  dateExpires : Date,
  previewImagePNGBase64 : String
  previewImageURL : String
  typeGroups : [TypeGroup]
}

Account = mongoose.model 'Account', AccountSchema
Session = mongoose.model 'Account.sessions', SessionSchema
Swyp = mongoose.model 'Swyp', SwypSchema
TypeGroup = mongoose.model 'Swyp.typeGroups', TypeGroupSchema
`Array.prototype.unique = function() {    var o = {}, i, l = this.length, r = [];    for(i=0; i<l;i+=1) o[this[i]] = this[i];    for(i in o) r.push(o[i]);    return r;};`

swypApp = require('zappa').app ->
  mongoose.connect(secrets.mongoDBConnectURLSecret)
  #removed , 'app.router' for mongooseAuth
  @use 'bodyParser', 'static', 'cookies', 'cookieParser', session: {secret: secrets.sessionSecret}
  #@use  mongooseAuth.middleware()
  #mongooseAuth.helpExpress @app
  
  crypto = require('crypto')

  @io.set("transports", ["xhr-polling"])
  @io.set("polling duration", 10)
 

  @get '*': ->
    if @request.headers['host'] == '127.0.0.1:3000'
      @next()
    else if @request.headers['x-forwarded-proto']!='https'
      @redirect "#{primaryHost}#{@request.url}"
    else
      @next()
  
  @include 'swypClient'
  @include 'swypUI'
  #process.on 'uncaughtException', (err) =>
  #  console.log "uncaught exception #{err} not terminating app"

  #this method performs a callback with (error, account, activeSessions) w. the relevant account for a publicUserID, as well as associated active sessions
  #public user id is the user._id for a user, which does not disclose their external credentials
  accountForPublicUserID = (publicID, callback) -> #callback(error, account, activeSessions)
    try
      objID = mongoose.mongo.BSONPure.ObjectID.fromString(publicID)
    catch err
      console.log "objID err: #{err} from publicid #{publicID}"
 
    Account.find {_id : objID}, (err, docs)  =>
      accountFound = docs[0] ? null
      if accountFound?
        activeSessions = activeSessionsForAccount(accountFound)
        callback null, accountFound, activeSessions
      else
        callback err, null, null
#this method asynchronously evaluates the validity of an Account session
  tokenValidate = (token, callback) ->
    accountFound = null
    session = null
    Account.find {"sessions.token" : token}, (err, docs)  =>
      accountFound = docs[0] ? null
      if accountFound != null
        accountFound.sessions.forEach (obj, i) ->
          if obj.token == token
            session = obj
      callback accountFound, session
#      console.log "found user #{accountFound} for session #{session} andtoken #{token}"
              #console.log sessionsForAccount

# checkyourselfbeforeyouwreckyourself.... asynchronous recersion, yo.
  recursiveGetAccountsAtLocationArray = (index, locationsArray, uniqueAccounts, callback) => #recursive function #callback(error, uniqueAccounts)
    maxDistanceRadial = 1/6378 #in radial coord km/radiusEarth *ONLY WORKS ON EARTH*
    nextAccounts = []
    nextAccounts = locationsArray if locationsArray?
    if locationsArray[index]?
      nextLocation = locationsArray[index]
      Account.find { "sessions.location" : { $nearSphere : nextLocation, $maxDistance : maxDistanceRadial }}, (err, docs) =>
        if err?
          console.log "error on session location lookup #{err}"
          callback err, null
          return
        if docs?
          nextAccounts = nextAccounts.concat(docs).unique()
          recursiveGetAccountsAtLocationArray(index + 1, locationsArray, nextAccounts, callback)
    else
      callback null, uniqueAccounts

# here we iterate over all active sessions near the old and new location of a session, then we update each session with its relevant nearby users
  updateUniqueActiveSessionsNearLocationArray = (locations, callback) => #callback(error)
    #console.log "updating nearby sessions to #{locations}"
    recursiveGetAccountsAtLocationArray 0,locations,[], (error, uniqueAccounts)=>
      #console.log "found relevant accounts #{uniqueAccounts.length}"
      activeSessions = []
      if (uniqueAccounts? == false || error?)
         console.log "no unique accounts or got error near #{locations}, err #{error}"
         return
      uniqueAccounts.forEach (obj, i) =>
        sessionsForAccount = activeSessionsForAccount obj
        if sessionsForAccount[0]?
          activeSessions = activeSessions.concat(sessionsForAccount)
      #console.log activeSessions
      for session in activeSessions
        relevantAccountsNearSession (session), (relevantUpdate, theSession) =>
          socket = socketForSession(theSession)
          if socket? && relevantUpdate?
            #console.log "nearbyrefreshing for sessionID #{theSession.socketID}"
            socket.emit('nearbyRefresh', relevantUpdate)

  accountsAndSessionsNearLocation = (location, callback) -> #callback([{sessions:[Session], account: Account}], allSessions)
    #for now we just return all active sessions for accounts with any nearby session
    recursiveGetAccountsAtLocationArray 0,[location],[], (error, uniqueAccounts)=>
      allSessions = []
      sessionsByAccount = []
      if err?
        console.log "error on session location lookup #{err}"
        return
      for obj in uniqueAccounts
        sessionsForAccount = activeSessionsForAccount obj
        if sessionsForAccount? &&  sessionsForAccount.length > 0
          sessionsByAccount.push([ obj, sessionsForAccount])
          allSessions = allSessions.concat(sessionsForAccount)
      console.log "#{allSessions.length}# active session local"
      callback(sessionsByAccount, allSessions)
  
  accountOwnsSession = (account, session) ->
    for ses in account.sessions
      if ses.token == session.token
        return true
    return false
  
  
  # in the callback you get a "sendval" as a "relevantUpdate," a ready-to-emit packet including users nearby w. their:
  # publicID: the internal mongo _id, instead of userID, to maintain email address confidentiality
  # username, the non-unique public id, and userImageURL
  relevantAccountsNearSession = (session, callback) -> #callback(relevantUpdate, theSession)
    Account.find {"sessions.location" : { $nearSphere : session.location, $maxDistance : 1/6378  }}, (err, docs) =>
      if err?
         console.log "error on session location lookup #{err}"
         return
      if docs?
        relevantAccounts = []
        for acc in docs
          if accountOwnsSession acc, session
            #console.log "acc #{acc.userID} owns session with token #{session.token}"
            sessionsForAccount = activeSessionsForAccount acc
            #if more than one active session for the current account, then good!
            if sessionsForAccount[1]?
              relevantAccounts.push acc
            else
             #console.log "current user w. session #{session.socketID} ignored bcuz only 1 session"
          else
            #console.log "acc #{acc.userID} does not own session with token #{session.token}"
            sessionsForAccount = activeSessionsForAccount acc
            if sessionsForAccount[0]?
              relevantAccounts.push acc
        #don't need to send session details to every client, we don't save, so this is NBD
        shareAccounts = []
        #for some reason there is a real need to uniquify
        relevantAccounts = relevantAccounts.unique()
        for acc in relevantAccounts
          shareAccounts.push {publicID: acc._id, userName: acc.userName, userImageURL: acc.userImageURL}
       
        #console.log "sessionToken #{session.token} gets accounts :"
        sendVal = {nearby: shareAccounts}
        callback sendVal, session
    
  socketForSession = (session) =>
    if @io.sockets.sockets[session.socketID]?
      return @io.sockets.sockets[session.socketID]
    else
      #console.log "session no socket #{session.socketID}"
      return null
  
  #grabs the active sessions for an accout, and returns in-line
  activeSessionsForAccount = (account) ->
    activeSessions = []
    if account.sessions?
      account.sessions.forEach (obj, i) =>
        if sessionIsActive obj
          activeSessions.push(obj)
    return activeSessions
  
  #returns whether a given session is active
  sessionIsActive = (session) =>
    if (socketForSession(session)?)
      return true
    else
      #console.log "not active #{socketForSession(session)}"
      return false

  @post '/signup', (req, res) ->
    userName   = req.body.user_name?.trim()
    userEmail = req.body.user_email?.trim().toLowerCase()
    userPassword = req.body.user_pass?.trim()
    if userName? and userPassword? and userEmail?
      newAccount = new Account {userPass: userPassword, userName: userName, userID: userEmail}
      
      #generate gravitar URL
      md5sum = crypto.createHash('md5')
      md5sum.update userEmail
      emailHash = md5sum.digest('hex')
      gravURL = "https://secure.gravatar.com/avatar/#{emailHash}?s=250&d=mm"
      newAccount.set {userImageURL: gravURL}
      newAccount.save (error) =>
        if error != null
          console.log "didFailSave", error
          console.log newAccount
          @render signup: {user_name: userName}
        else
          console.log "signup success for", userName
          @redirect '/token'
    else
      @render signup: {user_name: userName}
  

  @get '/signup': ->
    @render signup: {}
  
  @view signup: ->
    @title = 'signup'
    @stylesheets = ['/style']
    @scripts = ['/zappa/jquery','/zappa/zappa']
                                
    form method: 'post', action: '/signup', ->
      input id: 'user_name', type: 'text', name: 'user_name', placeholder: 'public username', size: 50
      input id: 'user_email', type: 'text', name: 'user_email', placeholder: 'login email', size: 50
      input id: 'user_pass', type: 'text', name: 'user_pass', placeholder: 'login pass', size: 50
      button 'signup'
  
  getTokenFromUserName = (userID, password, callback) => #callback(err, account, session)
    #console.log "finding #{userID}"
    Account.find {userID: userID}, (err, docs)  =>
      matchingUser = docs[0]
      #console.log 'docs',docs, 'with first', matchingUser
      if matchingUser? == false
        console.log "login failed for #{userID}"
        callback "baduser", null, null
        return

      if matchingUser.userPass != password
        console.log "login pass failed for #{matchingUser.userID}"
        matchingUser == null
        callback "badpass", null, null
        return
       
      if matchingUser != null
        console.log "match user"
        
        availableSessions = []
        for ses in matchingUser.sessions
          if (sessionIsActive ses) == false
            availableSessions.push(ses)

        if availableSessions.length == 0
          current_date = (new Date()).valueOf().toString()
          random = Math.random().toString()
          hash = crypto.createHash('sha1').update(current_date + random).digest('hex')
          newToken = "TOKENBLAH_#{matchingUser.userID}_#{hash}"
          console.log "Newtoken created #{newToken}"
          session =  new Session {token: newToken}
          matchingUser.sessions.push session
          matchingUser.save (error) =>
            if error != null
              console.log "didFailSave", error
            console.log "create new session success for", matchingUser.userID
            callback null, matchingUser, session
        else
          console.log "login session success for", matchingUser.userID
          previousSession = availableSessions[0]
          callback null, matchingUser, previousSession

  @get '/out', (req, res) -> #if no account, give a demo account
    token = @request.cookies.sessiontoken
    tokenValidate token, (user, session) =>
      if session? == false
        console.log "giving guest account for out"
        getTokenFromUserName 'guest','guest', (err, account, session) =>
         if err?
           req.render login: {error: err}
         else
           if @request.headers['host'] == '127.0.0.1:3000'
             req.response.cookie 'sessiontoken', session.token, {httpOnly: true, maxAge: 90000000000 }
           else
             req.response.cookie 'sessiontoken', session.token, {httpOnly: true, secure: true, maxAge: 90000000000 }
           req.redirect 'http://swyp.us/out'
      else
        console.log "user #{user.userName} has account for out"
        req.redirect 'http://swyp.us/out'
 
  @get '/in', (req, res) -> #if no account, give a demo account
    token = @request.cookies.sessiontoken
    tokenValidate token, (user, session) =>
      if session? == false
        console.log "giving guest account for in"
        getTokenFromUserName 'guest','guest', (err, account, session) =>
         if err?
           req.render login: {error: err}
         else
           if @request.headers['host'] == '127.0.0.1:3000'
             req.response.cookie 'sessiontoken', session.token, {httpOnly: true, maxAge: 90000000000 }
           else
             req.response.cookie 'sessiontoken', session.token, {httpOnly: true, secure: true, maxAge: 90000000000 }
           req.redirect '/'
      else
        console.log "user #{user.userName} has account for in"
        req.redirect '/'
 
  @get '/demo', (req, res) ->
     getTokenFromUserName 'guest','guest', (err, account, session) =>
      if err?
        req.render login: {error: err}
      else
        if @request.headers['host'] == '127.0.0.1:3000'
          req.response.cookie 'sessiontoken', session.token, {httpOnly: true, maxAge: 90000000000 }
        else
          req.response.cookie 'sessiontoken', session.token, {httpOnly: true, secure: true, maxAge: 90000000000 }
        req.redirect '/'
  
  @post '/login', (req, res) ->
    reqUserID  = req.body.user_id
    reqPassword = req.body.user_pass
    fbId = req.body.fb_uid
    fbToken = req.body.fb_token
    console.log "get token"
    req.response.clearCookie 'sessiontoken'
    getTokenFromUserName reqUserID,reqPassword, (err, account, session) =>
      if err?
        req.render login: {error: err}
      else
        if @request.headers['host'] == '127.0.0.1:3000'
          req.response.cookie 'sessiontoken', session.token, {httpOnly: true, maxAge: 90000000000 }
        else
          req.response.cookie 'sessiontoken', session.token, {httpOnly: true, secure: true, maxAge: 90000000000 }
        req.redirect '/'

  @get '/logout', (req, res)->
    req.response.clearCookie 'sessiontoken' # clear the cookie
    req.redirect '/'
  
  @get '/login': ->
    @render login: {ajax: @query.ajax?}
  
  @get '/token': ->
    @redirect '/login'

  @post '/token', (req, res) ->
    reqUserID  = req.body.user_id
    reqPassword = req.body.user_pass
    getTokenFromUserName reqUserID, reqPassword, (err, account, session) =>
      if err?
        req.render login: {error: err}
      else
        req.render login: {userID: matchingUser.userID, token: previousSession.token}
      
  @view login: ->
    if not @ajax
      @title = 'login'
      @stylesheets = ['/style']
      @scripts = ['/zappa/jquery','/zappa/zappa', '/login', '/md5']

    if @token != undefined && @userID != undefined
      div '#login', ->
        p "{\"userID\" : \"#{@userID}\", \"token\" : \"#{@token}\"}"
    else
      form '#login', method: 'post', action: '/login', ->
        img '#avatar', href: '#'
        input id: 'user_id', type: 'text', name: 'user_id', placeholder: 'login userid/email', size: 50
        input id: 'user_pass', type: 'text', name: 'user_pass', placeholder: 'login pass', size: 50
        button 'get token'
  
  @get '/preview/:id': (req, res) ->
    swypID = @params.id
    if swypID? == false
      @render 404: {status: 404}
      return
    swypForID swypID, (err, swyp) =>
      if swyp?
        console.log "got swyp id #{swyp._id}"
        if swyp.previewImagePNGBase64?
          @response.contentType 'image/jpeg'
          #console.log swyp.previewImagePNGBase64
          #@response.setHeader 'Content-Transfer-Encoding', 'base64'
          decodedImage = new Buffer swyp.previewImagePNGBase64, 'base64'
          @send decodedImage
          #@response.end swyp.previewImageJPG, 'binary'
        else
          @render 404: {status: 404}
      else
        console.log "no image for id #{swypID}"
        @render 404: {status: 404}
  
  @view 404: ->
    @title = "404, swyp off"
    h1 @title

  @get '/': ->
    sessionToken = null
    if @request.cookies.sessiontoken?
      sessionToken = @request.cookies.sessiontoken
    @render index: {token: sessionToken}
    console.log "resuming session of token #{sessionToken}"

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
      if @data.typeGroups? == false
        console.log "swypOut had bad typeGroupStructure"
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
