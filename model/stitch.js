secrets = require('../secrets');

crypto = require('crypto');

mongoose = require('mongoose');

Schema = mongoose.Schema;

ObjectId = mongoose.SchemaTypes.ObjectId;
exports.ObjectId = ObjectID

makeObjectID = mongoose.mongo.BSONPure.ObjectID.fromString
exports.makeObjectID = makeObjectID

SessionSchema = new Schema({
  sessionID: {
    type: String,
    required: true,
    index: {
      unique: true
    }
  },
  displayGroupID: {
    type: String,
    required: true,
    index: {
      unique: false
    }
  },
  physicalSize: {
    width: Number,
    height: Number
  },
  origin: {
    x: Number,
    y: Number
  }
});

DisplaySchema = new Schema({
  boundarySize: {
    width: Number,
    height: Number
  },
  contentURL: String,
  contentSize: {
    width: Number,
    height: Number
  }
});

SwypSchema = new Schema({
  sessionID: String,
  dateCreated: Date,
  swypPoint: {
    x: Number,
    y: Number
  },
  direction: String
});

Session = mongoose.model('Sessions', SessionSchema);
exports.Session = Session;

Swyp = mongoose.model('Swyp', SwypSchema);
exports.Swyp = Swyp;

DisplayGroup = mongoose.model('Display', DisplaySchema);
exports.DisplayGroup = DisplayGroup;

mongoose.connect(secrets.mongoDBConnectURLSecret);

exports.initializeConnection = function(socketID, callback) {
  if ((socketID != null) === false) {
    callback('no socketid included');
  }
};

exports.on_connection = function(socketID){
	var group = new DisplayGroup();
	var session = new Session();
	session.displayGroupID = group._id.toString();
	session.sessionID=socketID;
  	group.contentURL = 'http://i.imgur.com/Us4J3C4.jpg';
	group.save();
	session.save();
}
exports.on_disconnection = function(socketID, emitter) {
	Session.find({sessionID:socketID}, function (session){
      DisplayGroup.findOne({_id : makeObjectID(session.displayGroupID)}, function(err, displayGroup){
        update_all(displayGroup, emitter);
      });
    session.delete();
  });
}
exports.disaffiliate = function(socketID, emitter) {
	Session.findOne({sessionID:socketID}, function (err, session){
    var group = new DisplayGroup();
    group.boundarySize={"width":session.physicalSize.width, "height":session.physicalSize.height};
    group.save();
    session.displayGroupID = group._id.toString();
    session.origin={"x":0,"y":0};
    session.save();
    update_all(group, emitter);
  });
}
exports.on_swipe = function(swipe, emitter) {
	Session.findOne({sessionID: swipe.sessionID}, function(err, session) {

    session.physicalSize = swipe.screenSize;
    session.save(function(err, session) {

      DisplayGroup.findOne({_id : makeObjectID(session.displayGroupID)}, function(err, group) {
        var swyp = new Swyp({
          dateCreated: Date.now(), 
          swypPoint: swipe.swypPoint, 
          direction: swipe.direction
        }); // i'm high as a kite right now....
        // todo: save this swyp

        Swyp.find({
          "dateCreated": {"$gte": swyp.dateCreated - new Date(1000)}, 
          'direction': (swyp.direction == 'in' ? 'out' : 'in')
        }, function(err, swyps) {
          swyp.save();

          if(swyps.length == 0)
            return; // no matching swyp

          var swypIn, swypOut;
          if(swyps[0].direction == 'in')
            swypIn = swyps[0], swypOut = swyp;
          else
            swypIn = swyp, swypOut = swyps[0];



        }).limit(1);

    });


    //     if(swipe.direction=='out'){
				// 	Swyp.new({
    //         dateCreated: Date.now(), 
    //         swypPoint: swipe.swypPoint, 
    //         direction: swipe.direction
    //       }); // i'm high as a kite right now....
				// }
				else{
					Swyp.new(swipe); //same as above
					var swipes = connectingSwipe(swipe);
					var lastSwipeSession = {};
					Session.find({'sessionID': swyp2.sessionID}, 
						function(lastSwipeSession){
							var swipeCoord = {};
							if(swipes==false){
								return "no corresponding out-swipe within delta time";
							}
							else{
								//absolute coordinates of the swipe location
								swipeCoord.x=lastSwipeSession.origin.x+swipes[0].swypPoint.x;
									swipeCoord.y=lastSwipeSession.origin.y+swipes[0].swypPoint.y;
								//subtract distance from new device's origin to find new device's origin
								session.origin.x+=swipeCoord.x-swipes[1].swypPoint.x;
									session.origin.y+=swipeCoord.y-swipes[1].swypPoint.y;
								//add screen size to device origin to get new boundary size
								group.boundarySize.width=session.origin.x+session.physicalSize.width;
									group.boundarySize.width=session.origin.y+session.physicalSize.height;
								session.save();
								group.save();
							}
						});
				}
			update_all(group, emitter);
		});
	});
}

function update_all(DisplayGroup, emitter){
	Session.find({"displayGroupID": DisplayGroup._id.toString()}, function(err, sessions) {
    for (var i = 0; i < sessions.length; i++) {
      var socketID = sessions[i].sessionID;
      var data = {
        'url': DisplayGroup.contentURL,
        'boundarySize': DisplayGroup.boundarySize,
        'screenSize': sessions[i].physicalSize,
        'origin': sessions[i].origin
      };
      emitter(socketID, data);
    }
  });
}

function connectingSwipe(swipe){
	var end = swipe.dateCreated;
	var start = end-(new Date(1000));
	Swyp.find({"dateCreated": {"$gte": start, "$lt": end}}, function(results){swipes = result }).limit(2);
	if(swipes.length==2){
		//var swipeCoord = {"x":((swipes[0].swypPoint.x+swipes[1].swypPoint.x)/2), "y":((swipes[0].swypPoint.y+swipes[1].swypPoint.y)/2)};
		return swipes;
	}
	else{
		return false;
	}
}
