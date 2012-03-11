swypApp = require('zappa').app -> 
	@io.set("transports", ["xhr-polling"]); 
	@io.set("polling duration", 10); 

	@get '/': -> 
		@render index: {foo: 'bar'}

	@view index: ->
		@title = 'Inline template'
		h1 @title
		p @foo

	@view layout: ->
		doctype 5
		html ->
			head -> 
				title @title
				script src: '/socket.io/socket.io.js'
				script src: '/zappa/jquery.js'
				script src: '/zappa/zappa.js'
				script src: '/index.js'
			body @body

	@on connection: ->
		@emit welcome:  {time: new Date()}

	@client '/index.js': ->
		@on welcome: ->
		    $('body').append "Server time: #{@data.time}"
		
		@connect()

port = if process.env.PORT >0 then process.env.PORT else 3000
swypApp.app.listen port
