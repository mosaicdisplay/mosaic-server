@include = ->
  @client '/swyp.js': ->
    
    #type defs
    imageJPEGType = "image/jpeg"
    imagePNGType = "image/png"
    #swyp api data
    swypObjByID = []
    userLocation = [44.680997,10.317557] # a lng/lat pair

    supportedContentTypes = [imageJPEGType, imagePNGType] #in order of preference more->less

    setLocation = (pos)->
      console.log "updated location"
      userLocation = [pos.coords.longitude, pos.coords.latitude]
      makeStatusUpdate()

    if navigator.geolocation
      # no error handling for now
      navigator.geolocation.watchPosition(setLocation, null)

    $('document').ready ->
      $('#logout').click (e)->
        e.preventDefault()
        FB.logout (res)->
          console.log res
    $ =>
      $('#swypOut_button').click (e) =>
       pngFile = {
          contentURL : "http://swyp.us/guide/setupPhotos/setup1.png"
          contentMIME : imagePNGType
        }

       jpegFile = {
          contentURL : "http://fluid.media.mit.edu/people/natan/media/swyp/swyp.jpg"
          contentMIME : imageJPEGType
        }

        @emit swypOut: {token: localSessionToken(), previewImage: "NONE!", typeGroups: [pngFile, jpegFile]}
 
      $("#statusupdate_button").click ->
        makeStatusUpdate()
    
    localSessionToken = =>
      return $("#token_input").val()
    
    makeSwypIn = (swypObjID) =>
      if swypObjByID[swypObjID]?
        console.log "swyp in started for #{swypObjID}"
        swypObj = swypObjByID[swypObjID]
        commonTypes = supportedContentTypes.intersect(swypObj.availableMIMETypes)
        if commonTypes[0]?
          @emit swypIn: {token: localSessionToken(), id: swypObj.id, contentMIME:commonTypes[0]}
        else
          console.log "no common filetypes for swyp"
      else
        console.log "swypObj not stored for id#{swypObjID}"

    makeStatusUpdate = =>
      @emit statusUpdate: {token: localSessionToken(), location: userLocation}
 
    @on swypInAvailable: ->
      console.log @data
      swypObjByID[@data.id] = @data #{dateCreated: @data.dateCreated, id: @data.id, swypOuter: @data.swypOuter, availableMimeTypes: @data.availableMIMETypes}
      console.log "swyp in available #{@data.id}"
      $('body').append "<br /> @ #{@data.dateCreated} swypIn avail w.ID #{@data.id} from #{@data.swypOuter} with types: #{@data.availableMIMETypes}"
      $('body').append "<input id= 'button_#{@data.id}', type= 'button', value='swyp in!'>"
      $("#button_#{@data.id}").bind 'click', =>
          makeSwypIn(@data.id)


    @on swypOutPending: ->
      $('body').append "<br /> did swypOut @ #{@data.time} w.ID #{@data.id}"

    @on welcome: ->
      $('body').append "Welcome to swyp,  #{@data.time}"
    
    @on unauthorized: ->
      $('body').append "<br />You're currently not logged in. <a href='/login'>Login here</a>."
    
    @on updateGood: ->
      $('body').append "<br />you updated successfully! Cool yo!"
    
    @on nearbyRefresh: ->
      $('body').append "<br />received a nearby session update! w. nearby: #{JSON.stringify(@data.nearby)}"

    @on updateRequest: ->
      $('body').append "<br />update requested!"
      makeStatusUpdate()

    @on dataAvailable: ->
      $('body').append "<img src='#{@data.contentURL}' alt='imgID#{@data.id} of type #{@data.contentMIME}'/>"
     
    @connect()
