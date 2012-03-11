swyp = require('zappa').app -> 
	@get '/': 'hi'

swyp.app.listen 8080
