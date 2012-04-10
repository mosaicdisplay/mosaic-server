doctype 5
html ->
  head ->
    meta charset: 'utf-8'
    meta name:"viewport", content:"initial-scale=1.0, width=device-width, height=device-height, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no"
    
    title "#{@title or 'Untitled'} | Swyp"

  body ->
    @body
