(function() {
  var body, checkForCollisions, collides, force, friendClass, h, hideSwyp, instructions, isTouchDevice, isVisible, link, node, positionPreview, realTouches, receiveMessage, registerEvents, resize, setupBubbles, showBubblesAt, sourceWindow, vis, w, x, y;

  x = 0;

  y = 0;

  w = 0;

  h = 0;

  isVisible = false;

  node = void 0;

  link = void 0;

  sourceWindow = void 0;

  body = void 0;

  vis = void 0;

  force = d3.layout.force();

  instructions = {
    "default": "Drag the content onto the person you want to send it to.",
    drop: "Drop to send.",
    sending: "Sending now..."
  };

  isTouchDevice = "ontouchstart" in document.documentElement;

  realTouches = function(elem) {
    if (isTouchDevice) {
      return d3.touches(elem)[0];
    } else {
      return d3.mouse(elem);
    }
  };

  showBubblesAt = function(ex, ey) {
    vis.attr("class", "visible");
    isVisible = true;
    x = ex;
    y = ey;
    return force.start();
  };

  collides = function(el, ex, ey) {
    var rect;
    rect = el.getBoundingClientRect();
    if ((ex >= rect.left && ex <= rect.right) && (ey >= rect.top && ey <= rect.bottom)) {
      return true;
    }
    return false;
  };

  friendClass = function(d) {
    if (d.friend) {
      return "friend";
    } else {
      return "stranger";
    }
  };

  checkForCollisions = function(ex, ey) {
    var collisionCount;
    collisionCount = 0;
    node.each(function(d, i) {
      var collision;
      collision = collides(this, ex, ey);
      if (collision) collisionCount += 1;
      return d3.select(this).attr("class", (collision ? "hovered" : friendClass(d)));
    });
    return $("#instructions").text(instructions[(collisionCount > 0 ? "drop" : "default")]);
  };

  hideSwyp = function() {
    node.attr("class", friendClass);
    vis.attr("class", "hidden");
    $("#preview").hide();
    isVisible = false;
    if (sourceWindow != null) return sourceWindow.postMessage("HIDE_SWYP", "*");
  };

  resize = function() {
    w = body.attr("width");
    h = body.attr("height");
    force.size([w, h]);
    return vis.attr("width", w).attr("height", h);
  };

  positionPreview = function(ex, ey) {
    return $("#preview").css({
      left: ex - 25,
      top: ey - 25
    });
  };

  registerEvents = function() {
    var events, mouseEvents, touchEvents;
    touchEvents = ["touchstart", "touchmove", "touchend"];
    mouseEvents = ["mousedown", "mousemove", "mouseup"];
    events = (isTouchDevice ? touchEvents : mouseEvents);
    return body.on(events[0], function() {
      var bod, xy;
      bod = this;
      d3.event.preventDefault();
      d3.event.stopPropagation();
      xy = realTouches(bod);
      return showBubblesAt(xy[0], xy[1]);
    }).on(events[1], function(e) {
      var xy;
      if (isVisible) {
        xy = realTouches(this);
        $("#preview").show();
        positionPreview(xy[0], xy[1]);
        return checkForCollisions(xy[0], xy[1]);
      }
    }).on(events[2], function() {
      return hideSwyp();
    });
  };

  receiveMessage = function(event) {
    var eType, ex, ey, touches;
    console.log("RECEIVED: " + JSON.stringify(event.data));
    sourceWindow = event.source;
    eType = event.data.e;
    touches = event.data.touches;
    ex = touches[0] - 100;
    ey = touches[1] - 100;
    console.log(eType);
    if (eType === "dragstart") {
      console.log("show bubbles");
      positionPreview(ex, ey);
      $("#preview").attr("src", event.data.img);
      return showBubblesAt(ex, ey);
    }
  };

  setupBubbles = function() {
    body = d3.select("body");
    vis = body.append("svg:svg").attr("class", "hidden");
    return d3.json("graph.json", function(json) {
      force.nodes(json.nodes).links(json.links).gravity(0).distance(100).charge(-1000).start();
      link = vis.selectAll("line.link").data(json.links).enter().append("svg:line").attr("class", "link").attr("x1", function(d) {
        return d.source.x;
      }).attr("y1", function(d) {
        return d.source.y;
      }).attr("x2", function(d) {
        return d.target.x;
      }).attr("y2", function(d) {
        return d.target.y;
      });
      node = vis.selectAll("g.node").data(json.nodes).enter().append("svg:g").attr("class", function(d) {
        return friendClass;
      });
      node.filter(function(d, i) {
        return i !== 0;
      }).append("svg:rect").attr("class", "rect").attr("x", "-16px").attr("y", "-20px").attr("width", "200px").attr("height", "40px");
      node.append("svg:image").attr("class", "circle").attr("xlink:href", function(d) {
        return d.userImageURL;
      }).attr("x", "-16px").attr("y", "-20px").attr("width", "40px").attr("height", "40px");
      node.append("svg:text").attr("class", "nodetext").attr("dx", 32).attr("dy", ".35em").text(function(d) {
        return d.userName;
      });
      return force.on("tick", function(e) {
        resize();
        link.attr("x1", function(d) {
          return d.source.x;
        }).attr("y1", function(d) {
          return d.source.y;
        }).attr("x2", function(d) {
          return d.target.x;
        }).attr("y2", function(d) {
          return d.target.y;
        });
        return node.attr("transform", function(d) {
          var damper;
          if (d.index === 0) {
            damper = 0.1;
            d.x = x ? d.x + (x - d.x) * (damper + 0.71) * e.alpha : 400;
            d.y = y ? d.y + (y - d.y) * (damper + 0.71) * e.alpha : 400;
          }
          return "translate(" + d.x + "," + d.y + ")";
        });
      });
    });
  };

  $(function() {
    window.addEventListener("message", receiveMessage, false);
    setupBubbles();
    registerEvents();
    return $("#instructions").text(instructions["default"]);
  });

}).call(this);
