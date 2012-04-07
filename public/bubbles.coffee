x = 0 # the x pos of the mouse/touch event
y = 0 # y pos...
w = 0 # the svg width
h = 0 # ... height
isVisible = false # whether the bubbles are visible
node = undefined
link = undefined
sourceWindow = undefined
body = undefined
vis = undefined
force = d3.layout.force()

instructions =
  default: "Drag the content onto the person you want to send it to."
  drop:    "Drop to send."
  sending: "Sending now..."

isTouchDevice = "ontouchstart" of document.documentElement

realTouches = (elem) ->
  if isTouchDevice then d3.touches(elem)[0] else d3.mouse(elem)

# (re)display the bubbles, centered at the provided coordinates
showBubblesAt = (ex, ey) ->
  vis.attr "class", "visible"
  isVisible = true
  x = ex
  y = ey
  force.start()

# collision detection between an element and a touch/mouse x, y coord
collides = (el, ex, ey) ->
  rect = el.getBoundingClientRect()
  return true if (ex >= rect.left and ex <= rect.right) and (ey >= rect.top and ey <= rect.bottom)
  false

friendClass = (d) -> if d.friend then "friend" else "stranger"

# see if mouse/finger drag collides with a person bubble
checkForCollisions = (ex, ey) ->
  collisionCount = 0
  node.each (d, i) ->
    collision = collides(this, ex, ey)
    collisionCount += 1 if collision
    d3.select(this).attr "class", (if collision then "hovered" else friendClass(d))
  # update the instructions if dragging over a person
  $("#instructions").text instructions[(if (collisionCount > 0) then "drop" else "default")]

hideSwyp = ->
  node.attr "class", friendClass
  vis.attr "class", "hidden"
  $("#preview").hide()
  isVisible = false
  # send message to parent window if in iframe
  if sourceWindow? then sourceWindow.postMessage "HIDE_SWYP", "*"

# resize the force graph layout when the window is resized (happens each tick)
resize = ->
  w = body.attr("width")
  h = body.attr("height")
  force.size [ w, h ]
  vis.attr("width", w).attr("height", h)

# position the preview image that's currently being dragged
positionPreview = (ex, ey) ->
  $("#preview").css
    left: (ex - 25)
    top: (ey - 25)

# register for touch or mouse events based on device
registerEvents = ->
  touchEvents = [ "touchstart", "touchmove", "touchend" ]
  mouseEvents = [ "mousedown", "mousemove", "mouseup" ]
  
  events = (if isTouchDevice then touchEvents else mouseEvents)
  body.on(events[0], ->
    bod = this
    d3.event.preventDefault()
    d3.event.stopPropagation()
    xy = realTouches(bod)
    showBubblesAt xy[0], xy[1]
  ).on(events[1], (e) ->
    # only handle mouse moves if bubbles are visible
    if isVisible
      xy = realTouches(this)
      $("#preview").show()
      positionPreview xy[0], xy[1]
      checkForCollisions xy[0], xy[1]
  ).on(events[2], -> hideSwyp())

# respond to message when in iframe
receiveMessage = (event) ->
  console.log "RECEIVED: " + JSON.stringify(event.data)
  sourceWindow = event.source
  eType = event.data.e
  touches = event.data.touches
  ex = touches[0] - 100
  ey = touches[1] - 100
  console.log eType

  if eType is "dragstart"
    console.log "show bubbles"
    positionPreview ex, ey
    $("#preview").attr "src", event.data.img
    showBubblesAt ex, ey

# setup the bubbles
setupBubbles = (json)->
  body = d3.select("body")
  vis = body.append("svg:svg").attr("class", "hidden")

  force.nodes(json.nodes).links(json.links).gravity(0)
       .distance(100).charge(-1000).start()

  link = vis.selectAll("line.link").data(json.links).enter()
    .append("svg:line")
      .attr("class", "link")
      .attr("x1", (d) -> d.source.x)
      .attr("y1", (d) -> d.source.y)
      .attr("x2", (d) -> d.target.x)
      .attr("y2", (d) -> d.target.y)

  node = vis.selectAll("g.node").data(json.nodes).enter()
    .append("svg:g").attr("class", (d) -> friendClass)

  node.filter((d, i) -> i isnt 0)
    .append("svg:rect")
      .attr("class", "rect")
      .attr("x", "-16px")
      .attr("y", "-20px")
      .attr("width", "200px")
      .attr("height", "40px")
  # the user avatar
  node.append("svg:image")
      .attr("class", "circle")
      .attr("xlink:href", (d) -> d.userImageURL)
      .attr("x", "-16px")
      .attr("y", "-20px")
      .attr("width", "40px")
      .attr("height", "40px")
  # the user name
  node.append("svg:text")
      .attr("class", "nodetext")
      .attr("dx", 32)
      .attr("dy", ".35em").text (d) -> d.userName

  force.on "tick", (e) ->
    resize()
    link.attr("x1", (d) -> d.source.x)
        .attr("y1", (d) -> d.source.y)
        .attr("x2", (d) -> d.target.x)
        .attr("y2", (d) -> d.target.y)

    node.attr "transform", (d) ->
      # only translate the center node (index 0), the rest auto-follow
      if d.index is 0
        damper = 0.1
        d.x = if x then d.x + (x - d.x) * (damper + 0.71) * e.alpha else 400
        d.y = if y then d.y + (y - d.y) * (damper + 0.71) * e.alpha else 400
      "translate(#{d.x},#{d.y})"

$ ->
  window.addEventListener "message", receiveMessage, false
  $("#instructions").text instructions["default"]
  
  d3.json "graph.json", (json) ->
    setupBubbles(json)
    registerEvents()
