@title = 'Swyp Web Client'
@stylesheets = ['/style']
@scripts = ['/socket.io/socket.io',
            '/zappa/jquery',
            '/zappa/zappa',
            '/swyp']

if process.env.NODE_ENV is 'production'
  coffeescript ->
    window.app_id = '359933034051162'
else
  coffeescript ->
    window.app_id = '194436507332185'

script src: '/facebook.js'
script src: '/ArraySetMath.js'
            
h1 @title
input id: 'token_input', type: 'text', name: 'token_input', placeholder: 'session token', size: 50, value: 'TOKENBLAH_alex'
input id: 'statusupdate_button', type: 'button', value: "status update!"

input id: 'swypOut_button', type: 'button', value: "swyp out!"

div '#fb-root', ->
  a '#logout.hidden', href: "#", ->
    'Logout'
  div '#fb-login.fb-login-button.hidden', ->
    'Login with Facebook'


