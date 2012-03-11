swypApp = require('zappa').app -> 
  @use 'static'
  @enable 'default layout' # this is hella convenient

  @io.set("transports", ["xhr-polling"]); 
  @io.set("polling duration", 10); 

  @get '/': -> 
    @render index: {foo: 'bar', fb_id: secrets.fb.id}

  @view index: ->
    @title = 'Inline template'
    @stylesheets = ['/style']
    @scripts = ['/socket.io/socket.io', 
                '/zappa/jquery',
                '/zappa/zappa',
                '/index']

    coffeescript ->
      window.fbAsyncInit = ->
        FB.init {
          appId: '194436507332185',
          status: true, cookie: true, xfbml: true
        }

        FB.getLoginStatus (res)->
          switch res.status
            when 'connected'
              uid = res.authResponse.userID
              access_token = res.authResponse.accessToken
              console.log "authorized with uid: #{uid} and access token: #{access_token}"
            when 'not_authorized'
              console.log 'user is logged in, but has not authorized app'
            else
              $('.fb-login-button').show()

        FB.Event.subscribe 'auth.authResponseChange', (res)->
          console.log "The status of the session is: #{res.status}"

        return true

    script src: '/facebook.js'
                
    h1 @title
    p @foo
    div '#fb-root', ->
      div '.fb-login-button', ->
        'Login with Facebook'

  @on connection: ->
    @emit welcome:  {time: new Date()}

  @coffee '/facebook.js': ->
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
    @on welcome: ->
        $('body').append "Hey Ethan, socket.io says the time!: #{@data.time}"
    
    @connect()

port = if process.env.PORT > 0 then process.env.PORT else 3000
swypApp.app.listen port
