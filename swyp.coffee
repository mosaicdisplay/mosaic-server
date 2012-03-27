mongoose     = require('mongoose')
mongooseAuth = require('mongoose-auth')
Schema = mongoose.Schema
ObjectId = mongoose.SchemaTypes.ObjectId

#embedded schema as suggested http://mongoosejs.com/docs/embedded-documents.html
#   embedded seems to be the only way this works-- I had tried just literally embedding the properties (that didn't)
Session = new Schema {
  token : String,
  socketID : String,
  expiration : Date,
  location : [ Number, Number] #long,lat as suggested: http://www.mongodb.org/display/DOCS/Geospatial+Indexing 
}

AccountSchema = new Schema {
  userImageURL : String,
  userID : { type: String, index: { unique: true }},
  userName : { type: String, index: { unique: true }},
  userPass : String
  sessions : [Session]
}

###
Swyp Schema -- Determine whether embedded in session, or seperate
• Swyps created on swypOut event
• Swyps store track:
  - fileTypes [array of hashtables]
    - URL location
    - Requesting userIDs
  - swyp-out ownerID
  - expiration date
  - previewImage
###

UserSchema = new Schema {}

UserSchema.plugin mongooseAuth, {
  everymodule: {
    everyauth: {
      User: -> User
    }
  }
  facebook: true
  password: {
    loginWith: 'email'
    everyauth: {
        getLoginPath: '/login'
        postLoginPath: '/login'
        loginView: 'login.coffee'
        getRegisterPath: '/register'
        postRegisterPath: '/register'
        registerView: 'register.coffee'
        loginSuccessRedirect: '/'
        registerSuccessRedirect: '/'
    }
  }
  handleLogout: (req, res)->
    req.logout()
    res.json {'message': 'User logged out.'}
}

User = mongoose.model 'User', UserSchema
Account = mongoose.model 'Account', AccountSchema
mongoose.connect('mongodb://swyp:mongo4swyp2012@ds031587.mongolab.com:31587/heroku_app3235025')

swypApp = require('zappa').app ->
  @use 'bodyParser', 'static', 'cookieParser', session: {secret: 'gesturalsensation'}
  @app.use mongooseAuth.middleware()
  @enable 'default layout' # this is hella convenient

  @io.set("transports", ["xhr-polling"])
  @io.set("polling duration", 10)
 
#this is the new asynchronous method-- for now there's only one hardcoded token in @client code
  tokenValidate = (token, callback) ->
    userFound = null
    session = null
    Account.find {"sessions.token" : token}, (err, docs)  =>
      userFound = docs[0] ? null
      if userFound != null
        userFound.sessions.forEach (obj, i) ->
          if obj.token == token
            session = obj
      callback userFound, session
      console.log "found user #{userFound} for session #{session} andtoken #{token}"

  accountsAndSessionsNearLocation = (location, callback) -> #callback([{sessions:[Session], account: Account}])
    #for now we just return all active sessions for accounts with any nearby session
    sessionsByAccount = []
    Account.find { "sessions.location" : { $nearSphere : [44.680997,10.317557], $maxDistance : 1/6378 } }, (err, docs) =>
      if err?
        console.log "error on session location lookup #{err}"
        return
      if docs?
        docs.forEach (obj, i) =>
          activeSessionsForAccount obj, (sessionsForAccount) =>
            if sessionsForAccount? &&  sessionsForAccount.length > 0
              console.log "active session docs #{sessionsForAccount}"
              sessionsByAccount.push([ obj, sessionsForAccount])
      
      callback(sessionsByAccount)

  relevantAccountsAndSessionsForSession = (session, callback) -> #callback([{sessions:[Session], account: Account}])
    

  activeSessionsForAccount = (account, callback) => #callback([Session])
    activeSessions = []
    if account.sessions?
      account.sessions.forEach (obj, i) =>
        if (obj.expiration > new Date() || (obj.expiration?) == false) && @io.sockets.socket(obj.socketID)?
          activeSessions.push(obj)
    callback(activeSessions)

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
      input id: 'user_name', type: 'text', name: 'user_name', placeholder: 'login user', size: 50
      input id: 'user_pass', type: 'text', name: 'user_pass', placeholder: 'login pass', size: 50
      button 'signup'

  @post '/token', (req, res) ->
    console.log req.body
    reqName  = req.body.user_name
    reqPassword = req.body.user_pass
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
    @scripts = ['/zappa/jquery','/zappa/zappa']

    if @token != undefined && @userID != undefined
      p "{\"userID\" : \"#{@userID}\", \"token\" : \"#{@token}\"}"
    else
      form method: 'post', action: '/token', ->
        input id: 'user_name', type: 'text', name: 'user_name', placeholder: 'login user', size: 50
        input id: 'user_pass', type: 'text', name: 'user_pass', placeholder: 'login pass', size: 50
        button 'get token'
  
  @get '/': ->
    @render index: {}

  @view index: ->
    @title = 'Swyp Web Client'
    @stylesheets = ['/style']
    @scripts = ['/socket.io/socket.io',
                '/zappa/jquery',
                '/zappa/zappa',
                '/swyp']

    if process.env.NODE_ENV is 'production'
      coffeescript ->
        window.app_id = '359933034051162'
    else
      coffeescript ->
        window.app_id = '194436507332185'

    script src: '/facebook.js'
                
    h1 @title
    input id: 'token_input', type: 'text', name: 'token_input', placeholder: 'session token', size: 50, value: 'TOKENBLAH_alex'
    input id: 'statusupdate_button', type: 'button', value: "status update!"
   
    input id: 'swypOut_button', type: 'button', value: "swyp out!"

    div '#fb-root', ->
      a '#logout.hidden', href: "#", ->
        'Logout'
      div '#fb-login.fb-login-button.hidden', ->
        'Login with Facebook'

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
      session.location = location
      #console.log session.valueOf()
      user.save (error) => #[{"location":[44.680997,10.317557],"socketID":"1998803106463826141","token":"TOKENBLAH_alex"}]
        if error?
          console.log "error saving user after StatusUpdate #{ error }"
          @emit serverError: ->
        else
          @emit updateGood: ->
          accountsAndSessionsNearLocation location, (sessionsByAccount) =>
            for extAccount in sessionsByAccount
              for extSession in extAccount[1]
                if extSession != session
                  #this next part has got me stuck
                  #how do we update the nearby folks properly if this doesn't work? Check the logs, it emits, but it's never received as a packet.
                  console.log "External session to update #{extSession.socketID} w. socket #{@io.sockets.sockets[extSession.socketID]}"
                  @io.sockets.sockets[extSession.socketID].emit nearbyRefresh: {} if @io.sockets.sockets[extSession.socketID]?

  @on swypOut: ->
    tokenValidate @data.token, (user, session) =>
      if user == null
        @emit unauthorized: {}
        return
      #implement function to evaluate user token and abort if invalid
      contentID      = "newSwypID"
      supportedTypes = @data.fileTypes
      previewImage   = @data.previewImage
      recipientTo    = @data.to
      fromSender     = user
      swypTime       = new Date()
      console.log "swyp out created supports types #{supportedTypes}"
      @emit swypOutPending:
        {id: contentID, \
        time: swypTime}
      #will limit to nearby users later
      @broadcast swypInAvailable:
         {id: contentID, \
         fileTypes: supportedTypes,\
         preview: previewImage,\
         from: fromSender, \
         time: swypTime}
    
  @on swypIn: ->
    tokenValidate @data.token, (user, session) =>
      if user == null
        @emit unauthorized: {}
        return
      contentID   = @data.id
      contentType = @data.type
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
          $('#logout').removeClass('hidden')
          $('#fb-login').addClass('hidden')
        when 'not_authorized'
          console.log 'user is logged in, but has not authorized app'
        else # user is not logged in
          $('#logout').addClass('hidden')
          $('#fb-login').removeClass('hidden')

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

  @client '/swyp.js': ->
    $('document').ready ->
      $('#logout').click (e)->
        e.preventDefault()
        FB.logout (res)->
          console.log res
    $ =>
      $('#swypOut_button').click (e) =>
        @emit swypOut: {token: $("#token_input").val(), previewImage: "NONE!", fileTypes: ["image/png", "image/jpeg"]}
 
      $("#statusupdate_button").click ->
        makeStatusUpdate()

    makeStatusUpdate = =>
      @emit statusUpdate: {token: $("#token_input").val(), location: [44.680997,10.317557]}
 
    @on swypInAvailable: ->
      console.log "swyp in available"
      $('body').append "<br /> @ #{@data.time} swypIn avail w.ID #{@data.id} from #{@data.from.id} with types: #{@data.fileTypes}"

    @on swypOutPending: ->
      $('body').append "<br /> did swypOut @ #{@data.time} w.ID #{@data.id}"

    @on welcome: ->
      $('body').append "Hey Ethan, socket.io says the time!: #{@data.time}"
    
    @on unauthorized: ->
      $('body').append "<br />yo token is unauthorized, fo!!"
    
    @on updateGood: ->
      $('body').append "<br />you updated successfully!"
    
    @on nearbyRefresh: ->
      $('body').append "<br />received a nearby session update!"

    @on updateRequest: ->
      $('body').append "<br />update requested!"
      makeStatusUpdate()
     
    @connect()

port = if process.env.PORT > 0 then process.env.PORT else 3000
mongooseAuth.helpExpress swypApp.app
swypApp.app.listen port
console.log "starting on port # #{port}"
