swypUI =
  x: 0 # the x pos of the mouse/touch event
  y: 0 # y pos...
  w: 0 # the svg width
  h: 0 # ... height
  isVisible: false # whether the bubbles are visible
  node: undefined
  link: undefined
  sourceWindow: undefined
  body: undefined
  vis: undefined
  force: d3.layout.force()
  instructions:
    default: "Drag the content onto the person you want to send it to."
    drop:    "Drop to send."
    sending: "Sending now..."
  dataToSend: undefined #the data to be sent on swyp out
  pending: [] #any pending content for receipt
  canSwypIn: true #turn off to disable swyp ins

isTouchDevice = "ontouchstart" of document.documentElement

realTouches = (elem) ->
  if isTouchDevice then d3.touches(elem)[0] else d3.mouse(elem)

# (re)display the bubbles, centered at the provided coordinates
swypUI.showBubblesAt = (ex, ey) ->
  $('#instructions').show()
  @vis.attr "class", "visible"
  @isVisible = true
  @x = ex
  @y = ey
  @force.start()

# collision detection between an element and a touch/mouse x, y coord
collides = (el, ex, ey) ->
  rect = el.getBoundingClientRect()
  return true if (ex >= rect.left and ex <= rect.right) and (ey >= rect.top and ey <= rect.bottom)
  false

friendClass = (d) -> if d.friend then "friend" else "stranger"

# see if mouse/finger drag collides with a person bubble
checkForCollisions = (ex, ey, triggerSwypOut) ->
  collisionCount = 0
  swypUI.node.each (d, i) ->
    collision = collides(this, ex, ey)
    collisionCount += 1 if collision
    d3.select(this).attr "class", (if collision then "hovered" else friendClass(d))

    # this is how swyp outs are triggered!
    if collision and triggerSwypOut then swypUI.swypOut d

  # update the instructions if dragging over a person
  $("#instructions").text swypUI.instructions[(if (collisionCount > 0) then "drop" else "default")]

swypUI.swypOut = (d)->
  # alex, this is where you put relevant swyp out code
  alert "TRIGGERING SWYP OUT TO: #{JSON.stringify(d)} with data: #{JSON.stringify(swypUI.dataToSend)}"

swypUI.hideSwyp = ->
  console.log 'hiding swyp'
  @node.attr "class", friendClass
  @vis.attr "class", "hidden"
  $("#preview").hide()
  $("#instructions").hide()
  @isVisible = false
  # send message to parent window if in iframe
  if @sourceWindow? then @sourceWindow.postMessage "HIDE_SWYP", "*"

# resize the force graph layout when the window is resized (happens each tick)
swypUI.resize = ->
  @w = @body.attr("width")
  @h = @body.attr("height")
  @force.size [ @w, @h ]
  @vis.attr("width", @w).attr("height", @h)

# position the preview image that's currently being dragged
positionPreview = (ex, ey) ->
  $("#preview").css
    left: (ex - 25)
    top: (ey - 25)

touchEvents = [ "touchstart", "touchmove", "touchend" ]
mouseEvents = [ "mousedown", "mousemove", "mouseup" ]
eventsForDevice = (if isTouchDevice then touchEvents else mouseEvents)

# register for touch or mouse events based on device
swypUI.registerEvents = ->
  events = eventsForDevice
  @body.on(events[0], ->
    bod = this
    d3.event.preventDefault()
    d3.event.stopPropagation()
    xy = realTouches(bod)
    swypUI.showBubblesAt xy[0], xy[1]
  ).on(events[1], (e) ->
    # only handle mouse moves if bubbles are visible
    if swypUI.isVisible
      xy = realTouches(this)
      $("#preview").show()
      positionPreview xy[0], xy[1]
      checkForCollisions xy[0], xy[1], false
  ).on(events[2], ->
    if swypUI.isVisible
      xy = realTouches(this)
      # trigger swyp out on the collided people
      checkForCollisions xy[0], xy[1], true
      swypUI.hideSwyp()
  )

# respond to message when in iframe
swypUI.receiveMessage = (event) ->
  console.log "RECEIVED: " + JSON.stringify(event.data)
  swypUI.sourceWindow = event.source
  eType = event.data.e
  touches = event.data.touches
  ex = touches[0] - 100
  ey = touches[1] - 100
  console.log eType

  if eType is "dragstart"
    console.log "show bubbles"
    positionPreview ex, ey
    swypUI.dataToSend = event.data
    $("#preview").attr "src", event.data.img
    swypUI.showBubblesAt ex, ey

# setup the bubbles
swypUI.setupBubbles = (json)->
  if not @body then @body = d3.select("body")
  
  if @vis then $('svg').remove() # hack! BAD
  @vis = @body.append("svg:svg").attr("class", "hidden")

  @force.nodes(json.nodes).links(json.links).gravity(0)
       .distance(100).charge(-1000).start()

  @link = @vis.selectAll("line.link").data(json.links)
    
  @link.enter().append("svg:line")
      .attr("class", "link")
      .attr("x1", (d) -> d.source.x)
      .attr("y1", (d) -> d.source.y)
      .attr("x2", (d) -> d.target.x)
      .attr("y2", (d) -> d.target.y)

  @link.exit().remove()

  @node = @vis.selectAll("g.node").data(json.nodes)
  @node.enter()
       .append("svg:g").attr("class", (d) -> friendClass)

  @node.filter((d, i) -> i isnt 0)
    .append("svg:rect")
      .attr("class", "rect")
      .attr("x", "-16px")
      .attr("y", "-20px")
      .attr("width", "200px")
      .attr("height", "40px")
  # the user avatar
  @node.append("svg:image")
      .attr("class", "circle")
      .attr("xlink:href", (d) -> d.userImageURL)
      .attr("x", "-16px")
      .attr("y", "-20px")
      .attr("width", "40px")
      .attr("height", "40px")
  # the user name
  @node.append("svg:text")
      .attr("class", "nodetext")
      .attr("dx", 32)
      .attr("dy", ".35em").text (d) -> d.userName

  @node.exit().remove()

  @force.on "tick", (e) =>
    @resize()
    @link.attr("x1", (d) -> d.source.x)
         .attr("y1", (d) -> d.source.y)
         .attr("x2", (d) -> d.target.x)
         .attr("y2", (d) -> d.target.y)

    @node.attr "transform", (d) =>
      # only translate the center node (index 0), the rest auto-follow
      if d.index is 0
        damper = 0.1
        d.x = if @x then d.x + (@x - d.x) * (damper + 0.71) * e.alpha else 400
        d.y = if @y then d.y + (@y - d.y) * (damper + 0.71) * e.alpha else 400
      "translate(#{d.x},#{d.y})"


# Alex, this is how you add a new incoming swyp!
# expects an object: {objectID: 1, 
#                     userName:'Ethan', 
#                     thumbnailURL: 'http://...', 
#                     fullURL: 'http://...'}
swypUI.addPending = (item)->
  # will not add any swypIns if you turn canSwypIn off!
  if swypUI.canSwypIn
    # make sure not a duplicate
    for obj in swypUI.pending
      if obj.objectID is item.objectID
        return false

    swypUI.pending.push item
    $elem = $('<a/>').addClass('swyp_thumb').attr('id', "obj_#{item.objectID}")
                                            .attr('href', item.fullURL)
    $img = $('<img/>').attr('src', item.thumbnailURL)
    $span = $('<span/>').addClass('username').text(item.userName)
    $elem.append $img
    $elem.append $span
    $('body').append $elem

    i = swypUI.pending.length
    $elem.removeClass('top right bottom left')
    offset_margin = if i % 2 is 0 then 'left' else 'top'
    switch i % 4
      when 0 then $elem.addClass 'top'
      when 1 then $elem.addClass 'right'
      when 2 then $elem.addClass 'bottom'
      when 3 then $elem.addClass 'left'

    offset_base = Math.floor(i/4)
    offset_sign = if offset_base % 2 is 0 then -1 else 1
    offset = offset_sign*(60+Math.floor(Math.random()*180))
    $elem.css("margin-#{offset_margin}", "+=#{offset}")

    # bind events
    events = eventsForDevice
    $elem.on(events[2], (e)->
      if confirm "Accept content from #{item.userName}?"
        console.log "CONFIRMED"
        
        window.open item.fullURL, '_blank'
      $(this).hide() # either way, hide the content afterwards
    ).on('click', (e)-> e.preventDefault())

swypUI.demoObj = (fakeID)->
  fakeID ?= Math.floor(Math.random()*101)
  {objectID: fakeID, userName: 'Ethan Sherbondy', thumbnailURL: 'https://www.google.com/logos/2012/doisneau12-sr.png', fullURL: 'https://www.google.com/logos/2012/doisneau12-hp.jpg'}

swypUI.initialize = (json)->
  window.addEventListener "message", @receiveMessage, false
  $("#instructions").text @instructions["default"]
  @setupBubbles json
  @registerEvents()
  @addPending @demoObj()

window.swypClient = swypUI
