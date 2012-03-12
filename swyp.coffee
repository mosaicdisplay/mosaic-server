mongoose = require('mongoose')
mongoose.connect('mongodb://swyp:mongo4swyp2012@ds031587.mongolab.com:31587/heroku_app3235025')

swypApp = require('zappa').app -> 
  @use 'static'
  @enable 'default layout' # this is hella convenient

  @io.set("transports", ["xhr-polling"]); 
  @io.set("polling duration", 10); 

  @get '/': -> 
    @render index: {foo: 'bar'}

  @view index: ->
    @title = 'Inline template'
    @stylesheets = ['/style']
    @scripts = ['/socket.io/socket.io', 
                '/zappa/jquery',
                '/zappa/zappa',
                '/index']

    if process.env.NODE_ENV is 'production'
      coffeescript ->
        window.app_id = '359933034051162'
    else
      coffeescript ->
        window.app_id = '194436507332185'

    script src: '/facebook.js'
                
    h1 @title
    p @foo
    form ->
      button 'swypOut'

    div '#fb-root', ->
      a '#logout.hidden', href: "#", ->
        'Logout'
      div '.fb-login-button.hidden', ->
        'Login with Facebook'

  tokenEval = (token) -> 
    if token != "" 
      return {id: "userID"} #user lookup
    else return false; 

  @on connection: ->
    @emit welcome:  {time: new Date()}
  
  @on statusUpdate: ->
    if user = tokenEval(@data.token) == false
      @emit unauthorized: ->
      return
    location	= @data.location
    @emit updateGood: ->
    @broadcast nearbyRefresh:
      {preferred: [user],\
       otherNearby: "null"}

  @on swypOut: ->
    if user = tokenEval(@data.token) == false
      @emit unauthorized: ->
      return
    #implement function to evaluate user token and abort if invalid
    contentID 		= "newSwypID"
    supportedTypes	= @data.fileTypes 
    previewImage	= @data.previewImage
    recipientTo		= @data.to
    fromSender		= user 
    console.log "swyp out created supports types #{@supportedTypes}"
    @emit swypOutPending: ->
      {id: contentID}
    @broadcast swypInAvailable: -> #will limit to nearby users later
      {id: contentID, \
       fileTypes: supportedTypes,\
       preview: previewImage,\
       from: fromSender}
  
  @on swypIn: ->
    if user = tokenEval(@data.token) == false
      @emit unauthorized: ->
      return
    contentID 	= @data.id
    contentType = @data.type 
    uploadURL	= "http://newUploadURL"
    @emit dataPending: ->
      {id: contentID, \
       type: contentType}
    @broadcast dataRequest: ->
      {id: contentID, \
       type: contentType,
       uploadURL: uploadURL}
     
  @on uploadCompleted: ->
    if user = tokenEval(@data.token) == false
      @emit unauthorized: ->
      return
    contentID 	= @data.id
    contentType = @data.type 
    uploadURL	= "http://dbRetrievedUploadURL"
    console.log @io.sockets
    @broadcast dataAvailable: ->
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
          $('#logout').show()
        when 'not_authorized'
          console.log 'user is logged in, but has not authorized app'
        else # user is not logged in
          $('.fb-login-button').show()

    window.fbAsyncInit = ->
      FB.init {
        appId: app_id,
        status: true, cookie: true, xfbml: true
      }

      FB.getLoginStatus handleFBStatus
      FB.Event.subscribe 'auth.authResponseChange', handleFBStatus

      return true

    
    ((d)->
      js = id = 'facebook-jssdk'
      ref = d.getElementsByTagName('script')[0]
      if d.getElementById id then return
      js = d.createElement 'script'
      js.id = id
      js.async = true
      js.src = "//connect.facebook.net/en_US/all.js"
      ref.parentNode.insertBefore js, ref
    )(document)

  @client '/index.js': ->
    $('document').ready ->
      $('#logout').click (e)->
        e.preventDefault()
        FB.logout (res)->
          console.log res

    $ =>
      $('button').click (e) =>
        @emit swypOut: {token: "theToken", previewImage: "NONE!", supportedTypes: ["image/png", "image/jpeg"]}
        $('#box').val('').focus()
        e.preventDefault()

    @on welcome: ->
        $('body').append "Hey Ethan, socket.io says the time!: #{@data.time}"
    
    @connect()

port = if process.env.PORT > 0 then process.env.PORT else 3000
swypApp.app.listen port
