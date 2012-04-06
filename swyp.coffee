mongoose     = require('mongoose')
mongooseAuth = require('mongoose-auth')
Schema = mongoose.Schema

ObjectId = mongoose.SchemaTypes.ObjectId
User = null

UserSchema = new Schema {}
UserSchema.plugin mongooseAuth, {
  everymodule:
    everyauth:
      User: -> User
}

#sessions are contained within accounts, and represent an active connection to the swypServer
#sessions contain the socket.io socket id via 'socketID', and the current location of the user
Session = new Schema {
  token : String,
  socketID : String,
  expiration : Date,
  location : [ Number, Number] #long,lat as suggested: http://www.mongodb.org/display/DOCS/Geospatial+Indexing 
}

#the account schema contains the user information and login credentials
#the userIDs are unique, and can be universal identifiers (more internal than userName)
#the userName is the display name for other users to see
#the account document contains the session embeddedDocument 
AccountSchema = new Schema {
  userImageURL : String,
  userID : { type: String, index: { unique: true }},
  userName : { type: String, index: { unique: true }},
  userPass : String
  sessions : [Session]
}

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
# swypOuterID corresponds to a unique Account.userID
SwypSchema = new Schema {
  swypOuterID : String,
  swypRecipientID : String,
  dateCreated : Date,
  dateExpires : Date,
  previewImageJPG : String,
  typeGroups : [TypeGroup]
}

###
Swyp Schema -- Determine whether embedded in session, or seperate
• Swyps created on swypOut event
• Swyps stored track:
  - typeGroups [array of hashtables]
    - URL location
    - Requesting userIDs
  - swyp-out ownerID
  - expiration date
  - previewImage
###

Account = mongoose.model 'Account', AccountSchema
Swyp = mongoose.model 'Swyp', SwypSchema
TypeGroup = mongoose.model 'Swyp.typeGroups', TypeGroupSchema
`Array.prototype.unique = function() {    var o = {}, i, l = this.length, r = [];    for(i=0; i<l;i+=1) o[this[i]] = this[i];    for(i in o) r.push(o[i]);    return r;};`

swypApp = require('zappa').app ->
  @include 'secrets'
  #@mongoDBConnectURLSecret =  "mongodb://..."
  mongoose.connect(@mongoDBConnectURLSecret)

  @use 'bodyParser', 'static', 'cookieParser', session: {secret: @sessionSecret}
  @enable 'default layout' # this is hella convenient

  @io.set("transports", ["xhr-polling"])
  @io.set("polling duration", 10)
  
  @include 'swypClient'
  
  #this method performs a callback with (error, account, activeSessions) w. the relevant account for a userID, as well as associated active sessions
  accountForUserID = (userID, callback) -> #callback(error, account, activeSessions)
     Account.find {"userID" : userID}, (err, docs)  =>
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
    console.log "updating nearby sessions to #{locations}"
    recursiveGetAccountsAtLocationArray 0,locations,[], (error, uniqueAccounts)=>
      console.log "found relevant accounts #{uniqueAccounts.length}"
      activeSessions = []
      uniqueAccounts.forEach (obj, i) =>
        sessionsForAccount = activeSessionsForAccount obj
        if sessionsForAccount[0]?
          activeSessions = activeSessions.concat(sessionsForAccount)
      for session in activeSessions
        relevantAccountsNearSession (session), (relevantUpdate, theSession) =>
          socket = socketForSession(theSession)
          if socket? && relevantUpdate?
            console.log "nearbyrefreshing for sessionID #{theSession.socketID}"
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
      if ses._id == session._id
        return true
    return false
   
  relevantAccountsNearSession = (session, callback) -> #callback([{sessions:[Session], account: Account}], theSession)
    Account.find {"sessions.location" : { $nearSphere : session.location, $maxDistance : 1/6378  }}, {userName: 1, userImageURL: 1, sessions: 1} , (err, docs) =>
      if err?
         console.log "error on session location lookup #{err}"
         return
      if docs?
        relevantAccounts = []
        for acc in docs
          if accountOwnsSession acc, session
            sessionsForAccount = activeSessionsForAccount acc
            #if more than one active session for the current account, then good!
            if sessionsForAccount[1]?
              relevantAccounts.push acc
            else
              console.log "current user w. session #{session.socketID} ignored bcuz only 1 session"
          else
            relevantAccounts.push acc
        #don't need to send session details to every client, we don't save, so this is NBD
        for acc in relevantAccounts
          acc.sessions = undefined
        sendVal = {nearby: relevantAccounts}
        callback sendVal, session
    
  socketForSession = (session) =>
    if @io.sockets.sockets[session.socketID]?
      return @io.sockets.sockets[session.socketID]
    else
      console.log "session no socket #{session.socketID}"
      return null
  
  #grabs the active sessions for an accout, and returns in-line
  activeSessionsForAccount = (account) =>
    activeSessions = []
    if account.sessions?
      account.sessions.forEach (obj, i) =>
        if (obj.expiration > new Date() || (obj.expiration?) == false) && @io.sockets.socket(obj.socketID)?
          activeSessions.push(obj)
    return activeSessions
  
  @post '/signup', (req, res) ->
    userName   = req.body.user_name
    userPassword = req.body.user_pass
    if userName != "" and userPassword != ""
      newAccount = new Account()
      newAccount.set {userPass: userPassword}
      newAccount.set {userName: userName, userID: userName}
      newAccount.save (error) =>
        if error != null
          console.log "didFailSave", error
          console.log newAccount
          @render signup: {user_name: userName}
        else
          console.log "signup success for", uSerName
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
      input id: 'user_name', type: 'text', name: 'user_name', placeholder: 'login user', size: 50
      input id: 'user_pass', type: 'text', name: 'user_pass', placeholder: 'login pass', size: 50
      button 'signup'

  @post '/token', (req, res) ->
    console.log req.body
    reqName  = req.body.user_name
    reqPassword = req.body.user_pass
    fbId = req.body.fb_uid
    fbToken = req.body.fb_token

    Account.find {userName: reqName}, (err, docs)  =>
      matchingUser = docs[0]
      #console.log 'docs',docs, 'with first', matchingUser
      if matchingUser == null || matchingUser == undefined
        console.log "login failed for #{reqName}"
        @render login: {}
        return

      if matchingUser.userPass != reqPassword
        console.log "login pass failed for #{matchingUser.userName}"
        matchingUser == null
        @render login: {}
        return
       
      if matchingUser != null
        if matchingUser.sessions.length == 0
          newToken = "TOKENBLAH_#{matchingUser.userName}"
          console.log "Newtoken created #{newToken}"
          session = {token: newToken, socketID: @id}
          matchingUser.sessions.push session
          matchingUser.save (error) =>
            if error != null
              console.log "didFailSave", error
          console.log "create new session success for", matchingUser.userName
          @render login: {userID: matchingUser.userID, token: session.token}
        else
          previousSession = matchingUser.sessions[0]
          console.log previousSession
          @render login: {userID: matchingUser.userID, token: previousSession.token}

  @get '/token': ->
    @render login: {}

  @view login: ->
    @title = 'login'
    @stylesheets = ['/style']
    @scripts = ['/zappa/jquery','/zappa/zappa', '/facebook']

    if process.env.NODE_ENV is 'production'
      coffeescript ->
        window.app_id = '359933034051162'
    else
      coffeescript ->
        window.app_id = '194436507332185'

    if @token != undefined && @userID != undefined
      p "{\"userID\" : \"#{@userID}\", \"token\" : \"#{@token}\"}"
    else
      form method: 'post', action: '/token', ->
        input id: 'user_name', type: 'text', name: 'user_name', placeholder: 'login user', size: 50
        input id: 'user_pass', type: 'text', name: 'user_pass', placeholder: 'login pass', size: 50
        input id: 'fb_uid', type: 'hidden', name: 'fb_uid'
        input id: 'fb_token', type: 'hidden', name: 'fb_token'
        button 'get token'

    div '#fb-root', ->
      img '#fb_photo.hidden', src: ''
      a '#logout.hidden', href: "#", ->
        'Unlink Facebook account'
      div '#fb-login.fb-login-button.hidden', ->
        'Link account with Facebook'

  @get '/': ->
    @render index: {}

  @on connection: ->
    @emit updateRequest: {time: new Date()}
  
  @on statusUpdate: ->
    console.log "statusUpate"
    tokenValidate @data.token, (user, session) =>
      if user == null
        @emit unauthorized: {}
        return
      session.socketID = @id
      location  = @data.location
      oldLocation = session.location
      session.location = location
      #console.log session.valueOf()
      user.save (error) => #[{"location":[44.680997,10.317557],"socketID":"1998803106463826141","token":"TOKENBLAH_alex"}]
        if error?
          console.log "error saving user after StatusUpdate #{ error }"
          @emit serverError: ->
        else
          @emit updateGood: {}
          updateUniqueActiveSessionsNearLocationArray [location, oldLocation], (err) =>
            console.log err

  @on swypOut: ->
    tokenValidate @data.token, (user, session) =>
      if user == null
        @emit unauthorized: {}
        return
      #implement function to evaluate user token and abort if invalid
      supportedTypes = @data.typeGroups
      previewImage   = @data.previewImage
      recipientTo    = @data.to
      fromSender     = user.userID
      swypTime       = new Date()
      swypExpire = new Date(new Date().valueOf()+50) #expires in 50 seconds
     
      typeGroupsToSave = [] #this is for the datastore
      typeGroupsToSend = [] #this is for the swyp-out event
      if @data.typeGroups? == false
        console.log "swypOut had bad typeGroupStructure"
        @emit badData: {}
        return
      for type in @data.typeGroups
         typeGroupObj = new TypeGroup {contentMIME: type.contentMIME} #no upload or completion date or timeouts
         if type.contentURL?
           console.log "url included #{type.contentURL}"
           typeGroupObj.contentURL = type.contentURL
           typeGroupObj.uploadCompletionDate = new Date()
         typeGroupsToSave.push typeGroupObj #this gets saved
         typeGroupsToSend.push type.contentMIME #this gets emitted 

      nextSwyp = new Swyp {previewImage: previewImage, swypOuter: fromSender, dateCreated: swypTime, dateExpires: swypExpire, typeGroups: typeGroupsToSave}
      console.log nextSwyp
      nextSwyp.save (error) =>
        if error != null
          console.log "didFailSave", error
          return
        swypOutPacket = {id: nextSwyp._id, swypOuter: nextSwyp.swypOuter, dateCreated: nextSwyp.dateCreated, dateExpires: nextSwyp.dateExpires, availableMIMETypes: typeGroupsToSend}
        @emit swypOutPending: swypOutPacket #this sends only the MIMES
        console.log "new swypOut saved"
        accountsAndSessionsNearLocation session.location, (sessionsByAccount, allSessions) =>
          for toUpdateSession in allSessions
            socket = socketForSession(toUpdateSession)
            if socket? && toUpdateSession.socketID != session.socketID
               console.log "updating swypout for sessionID #{toUpdateSession.socketID}"
               socket.emit('swypInAvailable', swypOutPacket)
      #will limit to nearby users later
      ###
      @broadcast swypInAvailable:
         {id: contentID, \
         typeGroups: supportedTypes,\
         preview: previewImage,\
         from: fromSender, \
         time: swypTime}
      ###
  
  swypForID = (id, callback) => #{callback(err, swypObj)}
    objID = mongoose.mongo.BSONPure.ObjectID.fromString(id)
    Swyp.findOne {_id: objID}, (err, obj) =>
      if err? or (obj? == false)
         callback err, null
         console.log "no swyp for id #{id} found, w. err #{err}"
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
      if user == null
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
      if user == null
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

  @coffee '/facebook.js': ->
    handleFBStatus = (res)->
      switch res.status
        when 'connected'
          uid = res.authResponse.userID
          access_token = res.authResponse.accessToken
          console.log "authorized with uid: #{uid} and access token: #{access_token}"
          $("#fb_photo").removeClass("hidden").attr("src", "http://graph.facebook.com/#{uid}/picture")
          $('#fb_uid').val uid
          $('#fb_token').val access_token
          $('#logout').removeClass('hidden')
          $('#fb-login').addClass('hidden')
        when 'not_authorized'
          console.log 'user is logged in, but has not authorized app'
        else # user is not logged in
          $('#logout').addClass('hidden')
          $('#fb-login').removeClass('hidden')

    $('#logout').live 'click', (e)->
      FB.logout (res)->
        console.log res

    window.fbAsyncInit = ->
      FB.init {
        appId: app_id,
        status: true, cookie: true, xfbml: true
      }

      FB.getLoginStatus handleFBStatus
      FB.Event.subscribe 'auth.authResponseChange', handleFBStatus

    
    ((d)->
      js  = id = 'facebook-jssdk'
      ref = d.getElementsByTagName('script')[0]
      if d.getElementById id then return
      js = d.createElement 'script'
      js.id    = id
      js.async = true
      js.src   = "//connect.facebook.net/en_US/all.js"
      ref.parentNode.insertBefore js, ref
    )(document)

  #client code moved to swypClient.coffee

port = if process.env.PORT > 0 then process.env.PORT else 3000
swypApp.app.listen port
console.log "starting on port # #{port}"
