@title = 'Swyp Web Client'
@stylesheets = ['/style']
@scripts = ['/socket.io/socket.io',
            '/zappa/jquery',
            '/zappa/zappa',
            '/swyp',
            '/ArraySetMath']

h1 @title
input id: 'token_input', type: 'text', name: 'token_input', placeholder: 'session token', size: 50, value: @token
input id: 'statusupdate_button', type: 'button', value: "status update!"

input id: 'swypOut_button', type: 'button', value: "swyp out!"
