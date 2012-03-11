swypApp = require('zappa').app -> 
  @enable 'default layout' # this is hella convenient

  @io.set("transports", ["xhr-polling"]); 
  @io.set("polling duration", 10); 

  @get '/': -> 
    @render index: {foo: 'bar'}

  @view index: ->
    @title = 'Inline template'
    @scripts = ['/socket.io/socket.io', 
                '/zappa/jquery',
                '/zappa/zappa',
                '/index']
    h1 @title
    p @foo

  @on connection: ->
    @emit welcome:  {time: new Date()}

  @client '/index.js': ->
    @on welcome: ->
        $('body').append "Hey Ethan, socket.io says the time!: #{@data.time}"
    
    @connect()

port = if process.env.PORT > 0 then process.env.PORT else 3000
swypApp.app.listen port
