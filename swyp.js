(function() {
  var port, swypApp;

  swypApp = require('zappa').app(function() {
    this.use('static');
    this.enable('default layout');
    this.io.set("transports", ["xhr-polling"]);
    this.io.set("polling duration", 10);
    this.get({
      '/': function() {
        return this.render({
          index: {
            foo: 'bar',
            fb_id: secrets.fb.id
          }
        });
      }
    });
    this.view({
      index: function() {
        this.title = 'Inline template';
        this.stylesheets = ['/style'];
        this.scripts = ['/socket.io/socket.io', '/zappa/jquery', '/zappa/zappa', '/index'];
        coffeescript(function() {
          return window.fbAsyncInit = function() {
            FB.init({
              appId: '194436507332185',
              status: true,
              cookie: true,
              xfbml: true
            });
            FB.getLoginStatus(function(res) {
              var access_token, uid;
              switch (res.status) {
                case 'connected':
                  uid = res.authResponse.userID;
                  access_token = res.authResponse.accessToken;
                  return console.log("authorized with uid: " + uid + " and access token: " + access_token);
                case 'not_authorized':
                  return console.log('user is logged in, but has not authorized app');
                default:
                  return $('.fb-login-button').show();
              }
            });
            FB.Event.subscribe('auth.authResponseChange', function(res) {
              return console.log("The status of the session is: " + res.status);
            });
            return true;
          };
        });
        script({
          src: '/facebook.js'
        });
        h1(this.title);
        p(this.foo);
        return div('#fb-root', function() {
          return div('.fb-login-button', function() {
            return 'Login with Facebook';
          });
        });
      }
    });
    this.on({
      connection: function() {
        return this.emit({
          welcome: {
            time: new Date()
          }
        });
      }
    });
    this.coffee({
      '/facebook.js': function() {
        return (function(d) {
          var id, js, ref;
          js = id = 'facebook-jssdk';
          ref = d.getElementsByTagName('script')[0];
          if (d.getElementById(id)) return;
          js = d.createElement('script');
          js.id = id;
          js.async = true;
          js.src = "//connect.facebook.net/en_US/all.js";
          return ref.parentNode.insertBefore(js, ref);
        })(document);
      }
    });
    return this.client({
      '/index.js': function() {
        this.on({
          welcome: function() {
            return $('body').append("Hey Ethan, socket.io says the time!: " + this.data.time);
          }
        });
        return this.connect();
      }
    });
  });

  port = process.env.PORT > 0 ? process.env.PORT : 3000;

  swypApp.app.listen(port);

}).call(this);
