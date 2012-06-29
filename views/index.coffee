@title = 'Swyp Web Client'
@stylesheets = ['/style']
@scripts = ['/socket.io/socket.io',
            '/zappa/jquery',
            '/zappa/zappa',
            '/swyp',
            '/ArraySetMath',
            '/d3.v2.min',
            '/force',
            '/jquery-1.7.2.min',
            '/swypUI',
            '/login',
            '/md5']

h1 "#instructions",
img "#preview",

div '#account', ->
  if not @token
    a '#login_button', href:'#', -> 'Login/Register'
  else
    a '#logout_button', href: '/logout', -> 'Logout'


div '#debug', ->
  div 'swypStatusControls', ->
    input id: 'token_input', type: 'text', name: 'token_input', placeholder: 'session token', size: 50, value: @token
    input id: 'statusupdate_button', type: 'button', value: "status update!"

  div 'swypOutControls', ->
    input id: 'recipient_input', type: 'text', name: 'recipient_input', placeholder: 'recipient publicID or empty for nearby', size: 50
    input id: 'swypOut_button', type: 'button', value: "swyp out!"

  div '#swypMessages', ->
