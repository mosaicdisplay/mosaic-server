port = if process.env.PORT >0 then process.env.PORT else 3000
console.log 'launching to port ', port
require('zappa') 'swypserver.herokuapp.com', port, -> 
	@io.set("transports", ["xhr-polling"]); 
	@io.set("polling duration", 10); 

	@get '/': 'hi'
	
	@on connection: ->
		@emit welcome:  {time: new Date()}


