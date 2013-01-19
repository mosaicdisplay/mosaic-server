secrets = require ('../secrets')

mongoose = require('mongoose')
Schema = mongoose.Schema

ObjectId = mongoose.SchemaTypes.ObjectId

#authors are users
AuthorSchema = new Schema {
  modifiedDate: {type: Date, index: {unique: false}}
  displayName: String
  imageURI: String
  authorID: {type: String, required: true, index: {unique: true}}

  fbAccessToken: {type: String}
  facebookID: {type: Number, index: {unique: true}}
  isAdmin: {type: Boolean}

  activeSessionIDs: [ {type: String, index: {unique: true}} ]
  telephoneNumber: {type: String, index: {unique: false}}
  telephoneVerifyDate: {type: Date}
  telephoneNumberVerifyAttemptCount: {type: Number}
  telelphoneVerifyCode: {type: String}

  lastNotificationDate: {type: Date, index: {unique: false}}
  notificationInterval: {type: Number}
}

Author = mongoose.model 'Author', AuthorSchema
exports.Author = Author
  
mongoose.connect(secrets.mongoDBConnectURLSecret)

exports.authCurrentAuthorWithIDAndTokenForSession = (authorID, fbAToken, sessionToken, callback) -> #callback(err, author)
    if sessionToken? == false
      callback "no sessionToken included for authorID author lookup"
      return
    
    #Strategy 1: find existing session
    Author.findOne {activeSessionIDs: sessionToken},{}, (err, author) =>
      #console.log "found author w. ID #{author?.authorID} for session #{sessionToken}"
      if err? || author? == false
        if authorID? == false && fbAToken? == false
          #console.log "impossible to re-auth"
          callback "invalid session- and no re-auth route possible"
          return
        #strategy 2: query fb with fbAToken, then check for existing authorIDs of equal to FB's response
        authUserWithFacebookOfIDAndToken authorID, fbAToken, (err, fbUserID, fbResponse) =>
          if err? || ((fbUserID != authorID) && authorID? == true) ##if there is mismatch when authorID!=nil
            callback "could not find author with pre-id #{authorID} with fbID #{fbUserID} with error #{err}"
          else
            if authorID? == false
              #if prior authorID was unknown by request, we'll check to see if we have a match right now from FB
              console.log "using recursion to determine if fbUserID exists, now that we know it's #{fbUserID}"
              authCurrentAuthorWithIDAndTokenForSession fbUserID, fbAToken, sessionToken, callback
            else
              #we've authed the token using FB, and the userID probably exists
              imgURI = "https://graph.facebook.com/#{fbUserID}/picture?type=large&return_ssl_resources=1"
              authorInfo = {authorID: fbUserID, facebookID: fbUserID, fbAccessToken: fbAToken, imageURI: imgURI, authorDisplayName: fbResponse.name, modifiedDate: new Date()}
              authorInfo.metroAreaDisplayName = fbResponse.location?.name
              
              console.log "create the author! with info #{authorInfo}"
              Author.update {authorID: fbUserID},{$set: authorInfo, $push: { activeSessionIDs: sessionToken}}, {upsert: 1}, (err) ->
                if err?
                  callback "error for author save #{err} with info #{authorInfo}"
                else
                  console.log "saved new author with info #{authorInfo}, using recursion for auth"
                  authCurrentAuthorWithIDAndTokenForSession fbUserID, fbAToken, sessionToken, callback
      else
        callback null, author

exports.authUserWithFacebookOfIDAndToken = (fbID, fbToken, callback) -> #callback (err, fbUserID, responseData) #with err if invalid token
    if fbToken? == false
      callback "missing token for fb req"
      return
    requestURL = "https://graph.facebook.com/me?access_token=#{fbToken}"
    #console.log "doing request to fb with url: #{requestURL}"
    request requestURL, (error, response, body) ->
      if error? || response.statusCode != 200
        callback "fbreq err #{error} with code #{response.statusCode}"
        return
      resObjects = JSON.parse body
      if resObjects?.id != fbID
        console.log "fbreq mismatched fbID from req #{fbID} from server #{resObjects?.id}"
      if resObjects?.id? == false
        callback "no fbID returned for token #{fbToken}"
      else
        callback null, resObjects.id, resObjects

exports.getAuthorWithID = (authorID, callback) -> #callback(err, author, abreviatedInfo)
    Author.findOne {authorID: authorID},{fbAccessToken:0, facebookID: 0}, (err, author) =>
      if err? || author? == false
        callback "could not find author of id #{authorID} with error #{err}"
      else
        authorInfo = {imageURI: author.imageURI, authorID: author.authorID.toString(), metroAreaDisplayName: author.metroAreaDisplayName, authorDisplayName: author.authorDisplayName, ratingCount: author.ratingCount}
        callback null, author, authorInfo
