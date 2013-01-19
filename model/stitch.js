secrets = require('../secrets');

crypto = require('crypto');

mongoose = require('mongoose');

Schema = mongoose.Schema;

ObjectId = mongoose.SchemaTypes.ObjectId;

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

Swyp = mongoose.model('Swyp', SwypSchema);

DisplayGroup = mongoose.model('Display', DisplaySchema);

mongoose.connect(secrets.mongoDBConnectURLSecret);

exports.initializeConnection = function(socketID, callback) {
  if ((socketID != null) === false) {
    callback('no socketid included');
  }
};
var delta = new Date(1000); //stackoverflow says this is ms

exports.on_connection = function(socketID){
	var group = new DisplayGroup();
	var session = new Session();
	session.displayGroupID = group._id.toString();
	session.sessionID=socketID;
}
exports.on_disconnection = function(sesh){
	Session.find({sessionID:sesh.sessionID}).delete;
}
exports.disaffiliate = function(sesh){
	var group = new DisplayGroup();
	group.boundarySize={"width":sesh.physicalSize.width, "height":sesh.physicalSize.height};
	sesh.origin={"x":0,"y":0};
}
exports.on_swipe = function(swipe){
	var session= Session.find({_id : swipe.sessionID});
	var group= DisplayGroup.find({_id : session.displayGroupID});
	if(swipe.direction=='out'){
		Swyp.new(swipe); //I just want to create a row in the database as though it were void
	}
	else{
		Swyp.new(swipe); //same as above
		var swipes = connectingSwipe(swipe)
		var lastSwipeSession = Session.find({_id: swipes[0].sessionID});
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
	}
	return {"session":session,"displayGroup":group};
}
function connectingSwipe(swipe){
	var end = swipe.dateCreated;
	var start = end-delta;
	var swipes=Swyp.find({"dateCreated": {"$gte": start, "$lt": end}}).limit(2);
	if(swipes.length==2){
		//var swipeCoord = {"x":((swipes[0].swypPoint.x+swipes[1].swypPoint.x)/2), "y":((swipes[0].swypPoint.y+swipes[1].swypPoint.y)/2)};
		return swipes;
	}
	else{
		return false;
	}
}
