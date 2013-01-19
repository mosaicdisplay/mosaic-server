secrets = require ('../secrets')

crypto = require('crypto')
mongoose = require('mongoose')
Schema = mongoose.Schema

ObjectId = mongoose.SchemaTypes.ObjectId

ShorturlSchema = new Schema {
  modifiedDate: {type: Date, index: {unique: false}}
  redirectURI: {type: String, index: {unique: false}} #duplicates allowed
  shortURICode: {type: String, index: {unique: true}, required: true}
  isCustomCode: Boolean
  redirectCount: Number
  redirects: [{accessDate: Date, userInfo: {}}]
  creatorUserInfo: {}
}

Shorturl = mongoose.model 'Shorturl', ShorturlSchema
exports.Shorturl = Shorturl
  
mongoose.connect(secrets.mongoDBConnectURLSecret)


exports.shorten = (shorteningURI, minLength, domain, shouldReuseCode, customCode, userInfo, callback) -> #callback(err, shortURL<object>)
  #console.log "shortening #{shorteningURI}, len #{minLength} dom #{domain}, reuse #{shouldReuseCode}, custom #{customCode}, info #{userInfo}, callback #{callback}"
  if shorteningURI? == false
    callback 'no uri included for shortening'
    return
  if domain? == true && shorteningURI.substr(0,domain.length) != domain
    callback "invalid domain for shorteningURI: domain(#{domain}) uri(#{shorteningURI})"
    return
  if minLength? == false || minLength == 0
    minLength = 5
 
  genCode = (length) =>
    current_date = (new Date()).valueOf().toString()
    random = Math.random().toString()
    hash = crypto.createHash('sha1').update(current_date + random + shorteningURI).digest('base64')
    if length > hash.length
      return hash
    else return hash.substr(0, length)

  generateTries = 0

  addCodeToDatabase = (code, failCallback) => #failCallback(code, err, failCallback)
    setInfo = {modifiedDate: new Date(), shortURICode:code, creatorUserInfo:userInfo, isCustomCode: (customCode?), redirectURI: shorteningURI}
    #console.log setInfo
    short = new Shorturl setInfo
    short.save (err, savedShortURL) =>
      if err? == true
        failCallback code, err, failCallback
      else
        callback null, savedShortURL

  makeNewCode = () =>
    firstCode = customCode
    if firstCode? == false
      firstCode = genCode(minLength)
   
    #then we actually try inserting codes with this recursive cluster f
    addCodeToDatabase firstCode, (code, err, thisSameFunction) =>
      #---failcallback---
      if customCode?
        #if this was a custom code, the error has to do with intersection
        callback err
        return
      generateTries = generateTries + 1
      charsAdded = Math.floor(generateTries / 3)
      nextCode = genCode(minLength + charsAdded)
      addCodeToDatabase nextCode, thisSameFunction

  if shouldReuseCode
    Shorturl.findOne {redirectURI: shorteningURI, isCustomCode: false}, null, (error, shortened) =>
      if shortened?
        callback null, shortened
      else
        makeNewCode()
  else
    makeNewCode()
      

exports.retrieve = (shortURICode, userInfo, callback) -> #callback(err, shortURL)
  if shortURICode? == true
    #1 retrieve, 2 update
    Shorturl.findOne {shortURICode: shortURICode}, null, (err, shortened) ->
      if shortened? == false
        console.log "shortURILookup for #{shortURICode} failed w. error #{err}"
        callback "no shorturi redirect found"
        return
      else
        
        shortened.modifiedDate = new Date()
        if shortened.redirectCount? == false then shortened.redirectCount = 0
        shortened.redirectCount.$inc 1
        if shortened.redirects? == false then shortened.redirects = []
        shortened.redirects.$push {accessDate: new Date(), userInfo: userInfo }

        callback null, shortened
        #now we will update here, and return to callback before saving to avoid round-trip.
        
        shortened.save (err) =>
          if err? == true
            console.log "error updating stats for retreive #{err}"
  else
    callback "no shortURICode provided"


