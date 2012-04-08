(function() {
  var checkForCollisions, collides, friendClass, isTouchDevice, positionPreview, realTouches, swyp;

  swyp = {
    x: 0,
    y: 0,
    w: 0,
    h: 0,
    isVisible: false,
    node: void 0,
    link: void 0,
    sourceWindow: void 0,
    body: void 0,
    vis: void 0,
    force: d3.layout.force(),
    instructions: {
      "default": "Drag the content onto the person you want to send it to.",
      drop: "Drop to send.",
      sending: "Sending now..."
    }
  };

  isTouchDevice = "ontouchstart" in document.documentElement;

  realTouches = function(elem) {
    if (isTouchDevice) {
      return d3.touches(elem)[0];
    } else {
      return d3.mouse(elem);
    }
  };

  swyp.showBubblesAt = function(ex, ey) {
    this.vis.attr("class", "visible");
    this.isVisible = true;
    this.x = ex;
    this.y = ey;
    return this.force.start();
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
    swyp.node.each(function(d, i) {
      var collision;
      collision = collides(this, ex, ey);
      if (collision) collisionCount += 1;
      return d3.select(this).attr("class", (collision ? "hovered" : friendClass(d)));
    });
    return $("#instructions").text(instructions[(collisionCount > 0 ? "drop" : "default")]);
  };

  swyp.hideSwyp = function() {
    this.node.attr("class", friendClass);
    this.vis.attr("class", "hidden");
    $("#preview").hide();
    this.isVisible = false;
    if (this.sourceWindow != null) {
      return this.sourceWindow.postMessage("HIDE_SWYP", "*");
    }
  };

  swyp.resize = function() {
    this.w = this.body.attr("width");
    this.h = this.body.attr("height");
    this.force.size([this.w, this.h]);
    return this.vis.attr("width", this.w).attr("height", this.h);
  };

  positionPreview = function(ex, ey) {
    return $("#preview").css({
      left: ex - 25,
      top: ey - 25
    });
  };

  swyp.registerEvents = function() {
    var events, mouseEvents, touchEvents;
    touchEvents = ["touchstart", "touchmove", "touchend"];
    mouseEvents = ["mousedown", "mousemove", "mouseup"];
    events = (isTouchDevice ? touchEvents : mouseEvents);
    return this.body.on(events[0], function() {
      var bod, xy;
      bod = this;
      d3.event.preventDefault();
      d3.event.stopPropagation();
      xy = realTouches(bod);
      return swyp.showBubblesAt(xy[0], xy[1]);
    }).on(events[1], function(e) {
      var xy;
      if (swyp.isVisible) {
        xy = realTouches(this);
        $("#preview").show();
        positionPreview(xy[0], xy[1]);
        return checkForCollisions(xy[0], xy[1]);
      }
    }).on(events[2], function() {
      return swyp.hideSwyp();
    });
  };

  swyp.receiveMessage = function(event) {
    var eType, ex, ey, sourceWindow, touches;
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
      return this.showBubblesAt(ex, ey);
    }
  };

  swyp.setupBubbles = function(json) {
    var _this = this;
    if (!this.body) this.body = d3.select("body");
    if (!this.vis) {
      this.vis = this.body.append("svg:svg").attr("class", "hidden");
    } else {
      this.vis = d3.select("svg");
    }
    this.force.nodes(json.nodes).links(json.links).gravity(0).distance(100).charge(-1000).start();
    this.link = this.vis.selectAll("line.link").data(json.links);
    this.link.enter().append("svg:line").attr("class", "link").attr("x1", function(d) {
      return d.source.x;
    }).attr("y1", function(d) {
      return d.source.y;
    }).attr("x2", function(d) {
      return d.target.x;
    }).attr("y2", function(d) {
      return d.target.y;
    });
    this.link.exit().remove();
    this.node = this.vis.selectAll("g.node").data(json.nodes);
    this.node.enter().append("svg:g").attr("class", function(d) {
      return friendClass;
    });
    this.node.filter(function(d, i) {
      return i !== 0;
    }).append("svg:rect").attr("class", "rect").attr("x", "-16px").attr("y", "-20px").attr("width", "200px").attr("height", "40px");
    this.node.append("svg:image").attr("class", "circle").attr("xlink:href", function(d) {
      return d.userImageURL;
    }).attr("x", "-16px").attr("y", "-20px").attr("width", "40px").attr("height", "40px");
    this.node.append("svg:text").attr("class", "nodetext").attr("dx", 32).attr("dy", ".35em").text(function(d) {
      return d.userName;
    });
    this.node.exit().remove();
    return this.force.on("tick", function(e) {
      _this.resize();
      _this.link.attr("x1", function(d) {
        return d.source.x;
      }).attr("y1", function(d) {
        return d.source.y;
      }).attr("x2", function(d) {
        return d.target.x;
      }).attr("y2", function(d) {
        return d.target.y;
      });
      return _this.node.attr("transform", function(d) {
        var damper;
        if (d.index === 0) {
          damper = 0.1;
          d.x = _this.x ? d.x + (_this.x - d.x) * (damper + 0.71) * e.alpha : 400;
          d.y = _this.y ? d.y + (_this.y - d.y) * (damper + 0.71) * e.alpha : 400;
        }
        return "translate(" + d.x + "," + d.y + ")";
      });
    });
  };

  swyp.initialize = function(json) {
    window.addEventListener("message", this.receiveMessage, false);
    $("#instructions").text(instructions["default"]);
    this.setupBubbles(json);
    return this.registerEvents();
  };

  window.swypClient = swyp;

}).call(this);
