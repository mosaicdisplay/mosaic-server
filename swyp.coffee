swyp = require('zappa').app -> 
	@get '/': 'hi'
	
	@on connection: ->
		@emit welcome:  {time: new Date()}

swyp.app.listen process.env.PORT || 3000;
