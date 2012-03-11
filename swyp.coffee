swyp = require('zappa').app -> 
	@get '/': 'hi'

swyp.app.listen process.env.PORT || 3000;
