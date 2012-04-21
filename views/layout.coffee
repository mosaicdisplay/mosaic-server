doctype 5
html ->
  head ->
    meta charset: 'utf-8'
    meta name:"viewport", content:"width=device-width; height=device-height; initial-scale=1.0; maximum-scale=1.0; user-scalable=no"
    meta name: "apple-mobile-web-app-capable", content:"yes"
    
    title "#{@title or 'Untitled'} | Swyp"

    if @scripts
      for s in @scripts
        script src: s + '.js'
    script(src: @script + '.js') if @script
    if @stylesheets
      for s in @stylesheets
        link rel: 'stylesheet', href: s + '.css'
    link(rel: 'stylesheet', href: @stylesheet + '.css') if @stylesheet
    style @style if @style

  body ->
    @body
