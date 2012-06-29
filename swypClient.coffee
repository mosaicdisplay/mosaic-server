@include = ->
  @client '/swyp.js': ->
    window.swyp = {}
    
    #type defs
    imageJPEGType = "image/jpeg"
    imagePNGType = "image/png"
    #swyp api data
    swypObjByID = []
    userLocation = [44.680997,10.317557] # a lng/lat pair

    window.swyp.supportedContentTypes = [imageJPEGType, imagePNGType] #in order of preference more->less
    
    window.swyp.dataAvailableCallback = null #this gets called after swypIn function(swypInfo, error)


    setLocation = (pos)->
      console.log "updated location"
      userLocation = [pos.coords.longitude, pos.coords.latitude]
      makeStatusUpdate()

    if navigator.geolocation
      # no error handling for now
      navigator.geolocation.watchPosition(setLocation, null)

    $ =>
      window.swyp.isSignedIn = (localSessionToken())?
      console.log window.swyp.isSignedIn
      
      #d3.json "graph.json", (json) ->
      swypClient.initialize {nodes:[], links:[]}
    
    localSessionToken = =>
      #this is really such a hack, I think... 
      token = $("#token_input").val()
      if token == "" || token? == false
        return null
      else return token
    
    makeSwypOut = (swypRecipient, previewBase64Image, previewImageURL, swypTypeGroups) =>
        toRecipient = swypRecipient?.trim()
        console.log "swyp goes to recip #{toRecipient}"
        @emit swypOut: {token: localSessionToken(), to: toRecipient, previewImagePNGBase64: previewBase64Image, previewImageURL: previewImageURL, typeGroups: swypTypeGroups}
    window.swyp.makeSwypOut = makeSwypOut

    #the client makes a swyp in, using the to: property if they wish to specifiy it to a specifc account._id
    makeSwypIn = (swypObjID) =>
      if swypObjByID[swypObjID]?
        console.log "swyp in started for #{swypObjID}"
        swypObj = swypObjByID[swypObjID]
        commonTypes = swyp.supportedContentTypes.intersect(swypObj.availableMIMETypes)
        if commonTypes[0]?
          @emit swypIn: {token: localSessionToken(), id: swypObj.id, contentMIME:commonTypes[0]}
        else
          console.log "no common filetypes for swyp"
      else
        console.log "swypObj not stored for id#{swypObjID}"
    window.swyp.makeSwypIn = makeSwypIn

    makeStatusUpdate = =>
      @emit statusUpdate: {token: localSessionToken(), location: userLocation}
    window.swyp.makeStatusUpdate = makeStatusUpdate
 
    @on swypInAvailable: ->
      console.log @data
      swypObjByID[@data.id] = @data #{dateCreated: @data.dateCreated, id: @data.id, swypSender: @data.swypSender, availableMimeTypes: @data.availableMIMETypes}
      console.log "swyp in available #{@data.id}"
      #$('#swypMessages').append "<br /> @ #{@data.dateCreated} swypIn avail w.ID #{@data.id} from #{@data.swypSender} with types: #{@data.availableMIMETypes} <img src='#{@data.swypSender.userImageURL}' /> <img src='#{@data.previewImageURL}' />"
      #$('#swypMessages').append "<input id= 'button_#{@data.id}', type= 'button', value='swyp in!'>"
      #$("#button_#{@data.id}").bind 'click', =>
      #    makeSwypIn(@data.id)
      swypClient.addPending {objectID: @data.id, userName: @data.swypSender.userName, userImageURL: @data.swypSender.userImageURL, thumbnailURL: @data.previewImageURL}


    @on swypOutPending: ->
      console.log "<br /> did swypOut @ #{@data.time} w.ID #{@data.id}"

    @on welcome: ->
      #$('#swypMessages').append "Welcome to swyp,  #{@data.time}"
    
    @on unauthorized: ->
      $('#swypMessages').append "<br />You're currently not logged in."
    
    @on updateGood: ->
      console.log "<br />you updated successfully! Cool yo!"
    
    @on nearbyRefresh: ->
      newNearbyDataString = JSON.stringify(@data.nearby)
      console.log "<br />received a nearby session update! w. nearby: #{newNearbyDataString}"

      if swypClient.lastNearbyData == newNearbyDataString
        console.log "equal update"
        return
      else
        console.log "not equal-- last one", swypClient.lastNearbyData
        swypClient.lastNearbyData = newNearbyDataString

      peers = @data.nearby
      graph = {nodes:[{userName:"Your Room",publicID:"",userImageURL:"", friend:true}], links:[]}
      i = 1
      for peer in peers
        graph.nodes.push({userName:peer.userName,publicID:peer.publicID, userImageURL:peer.userImageURL, friend:false})
        graph.links.push({source:i, target:0})
        i += 1

      swypClient.setupBubbles graph


    @on updateRequest: ->
      console.log "<br />update requested!"
      makeStatusUpdate()

    @on dataAvailable: ->
      console.log "data available #{@data.contentURL}"
      swyp.dataAvailableCallback @data, null
      console.log "<img src='#{@data.contentURL}' alt='imgID#{@data.id} of type #{@data.contentMIME}'/>"
     
    @connect()
