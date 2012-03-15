@title = "Login"

h1 "Login"

if @errors?
  ul '#errors', ->
    (li '.error', -> error) for error in @errors

form action:'/login', method:'POST', ->
  #login
  login = @everyauth.password.loginFormFieldName
  label for:login, -> "Login"
  input "##{login}", type:'text', name:login, value:@email

  #password
  pw = @everyauth.password.passwordFormFieldName
  label for:pw, -> "Password"
  input "##{pw}", name:pw, type:'password', -> pw

  #submit
  input type:'submit', -> "Login"
