swypApp = require('zappa').app -> 
	@io.set("transports", ["xhr-polling"]); 
	@io.set("polling duration", 10); 

	@get '/': 'hi'
	
	@on connection: ->
		@emit welcome:  {time: new Date()}

port = if process.env.PORT >0 then process.env.PORT else 3000
swypApp.app.listen port
