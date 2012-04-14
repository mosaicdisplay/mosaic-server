(function() {
  var checkForCollisions, collides, eventsForDevice, friendClass, isTouchDevice, mouseEvents, positionPreview, realTouches, swyp, touchEvents;

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
    },
    pending: [],
    canSwypIn: true
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
    $('#instructions').show();
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
    return $("#instructions").text(swyp.instructions[(collisionCount > 0 ? "drop" : "default")]);
  };

  swyp.hideSwyp = function() {
    console.log('hiding swyp');
    this.node.attr("class", friendClass);
    this.vis.attr("class", "hidden");
    $("#preview").hide();
    $("#instructions").hide();
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

  touchEvents = ["touchstart", "touchmove", "touchend"];

  mouseEvents = ["mousedown", "mousemove", "mouseup"];

  eventsForDevice = (isTouchDevice ? touchEvents : mouseEvents);

  swyp.registerEvents = function() {
    var events;
    events = eventsForDevice;
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
        $("#swypMessages").html("");
        $("#swypMessages").append($("<p/>").text("touch x: " + xy[0] + ", y: " + xy[1]));
        swyp.node.each(function(d, i) {
          return $("#swypMessages").append($("<p/>").text(JSON.stringify(this.getBoundingClientRect()) + " collision: " + collides(this, xy[0], xy[1])));
        });
        return checkForCollisions(xy[0], xy[1]);
      }
    }).on(events[2], function() {
      return swyp.hideSwyp();
    });
  };

  swyp.receiveMessage = function(event) {
    var eType, ex, ey, touches;
    console.log("RECEIVED: " + JSON.stringify(event.data));
    swyp.sourceWindow = event.source;
    eType = event.data.e;
    touches = event.data.touches;
    ex = touches[0] - 100;
    ey = touches[1] - 100;
    console.log(eType);
    if (eType === "dragstart") {
      console.log("show bubbles");
      positionPreview(ex, ey);
      $("#preview").attr("src", event.data.img);
      return swyp.showBubblesAt(ex, ey);
    }
  };

  swyp.setupBubbles = function(json) {
    var _this = this;
    if (!this.body) this.body = d3.select("body");
    if (this.vis) $('svg').remove();
    this.vis = this.body.append("svg:svg").attr("class", "hidden");
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

  swyp.addPending = function(item) {
    var $elem, $img, $span, events, i, obj, offset, offset_base, offset_margin, offset_sign, _i, _len, _ref;
    _ref = swyp.pending;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      obj = _ref[_i];
      if (obj.objectID === item.objectID) return false;
    }
    swyp.pending.push(item);
    $elem = $('<a/>').addClass('swyp_thumb').attr('id', "obj_" + item.objectID).attr('href', item.fullURL);
    $img = $('<img/>').attr('src', item.thumbnailURL);
    $span = $('<span/>').addClass('username').text(item.userName);
    $elem.append($img);
    $elem.append($span);
    $('body').append($elem);
    i = swyp.pending.length;
    $elem.removeClass('top right bottom left');
    offset_margin = i % 2 === 0 ? 'left' : 'top';
    switch (i % 4) {
      case 0:
        $elem.addClass('top');
        break;
      case 1:
        $elem.addClass('right');
        break;
      case 2:
        $elem.addClass('bottom');
        break;
      case 3:
        $elem.addClass('left');
    }
    offset_base = Math.floor(i / 4);
    offset_sign = offset_base % 2 === 0 ? -1 : 1;
    offset = offset_sign * (60 + Math.floor(Math.random() * 180));
    $elem.css("margin-" + offset_margin, "+=" + offset);
    events = eventsForDevice;
    return $elem.on(events[2], function(e) {
      if (confirm("Accept content from " + item.userName + "?")) {
        console.log("CONFIRMED");
        window.open(item.fullURL, '_blank');
      }
      return $(this).hide();
    }).on('click', function(e) {
      return e.preventDefault();
    });
  };

  swyp.demoObj = function(fakeID) {
    if (fakeID == null) fakeID = Math.floor(Math.random() * 101);
    return {
      objectID: fakeID,
      userName: 'Ethan Sherbondy',
      thumbnailURL: 'https://www.google.com/logos/2012/doisneau12-sr.png',
      fullURL: 'https://www.google.com/logos/2012/doisneau12-hp.jpg'
    };
  };

  swyp.initialize = function(json) {
    window.addEventListener("message", this.receiveMessage, false);
    $("#instructions").text(this.instructions["default"]);
    this.setupBubbles(json);
    this.registerEvents();
    return this.addPending(this.demoObj());
  };

  window.swypClient = swyp;

}).call(this);
