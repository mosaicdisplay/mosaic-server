@include = ->
  @client '/swyp.js': ->
    window.swyp = {}
    
    #type defs
    imageJPEGType = "image/jpeg"
    imagePNGType = "image/png"
    #swyp api data
    swypObjByID = []
    userLocation = [44.680997,10.317557] # a lng/lat pair

    swyp.supportedContentTypes = [imageJPEGType, imagePNGType] #in order of preference more->less

    setLocation = (pos)->
      console.log "updated location"
      userLocation = [pos.coords.longitude, pos.coords.latitude]
      makeStatusUpdate()

    if navigator.geolocation
      # no error handling for now
      navigator.geolocation.watchPosition(setLocation, null)

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
        
        base64PreviewImage = "/9j/4AAQSkZJRgABAgAAZABkAAD/7AARRHVja3kAAQAEAAAADQAA/+4ADkFkb2JlAGTAAAAAAf/bAIQAExAQGBEYJhcXJjAlHiUwLCUkJCUsOzMzMzMzO0M+Pj4+Pj5DQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQwEUGBgfGx8lGBglNCUfJTRDNCkpNENDQ0AzQENDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0ND/8AAEQgAOAAoAwEiAAIRAQMRAf/EAHoAAAEFAQEAAAAAAAAAAAAAAAACAwQGBwEFAQADAQEAAAAAAAAAAAAAAAAAAgMBBBAAAgEDAgMGBAcAAAAAAAAAAQIAERIDITFBsQRRYZEiMgWh0UJycYFSYpITFBEAAwACAgMBAAAAAAAAAAAAAAERIQJREkFSA4H/2gAMAwEAAhEDEQA/AKvLd0/snQ5caM7UJ3Fe6VQrwmmp5EQWg+VfGkb6puRwNGlaqVzL7J0SoSpqwFQLp4PXe25eiKkgnG4uR+75iaLRSNRrIXV+348mF1YkqVOhPdJ6dtXl1DbRrChnNBwhOiE6iAoiaemMtjTX6V5TMiJqOJLsaV4BeUT6eBtRkmh18IrI1+JtNlblHTiFdYnKKYm+1uUj5KGWU0hFCE64QFRz/RlH1t/IyYPcWvLnGrXAVBPZUHhQVB4AbRWHrXAvtLWooZhpVrhq2+loC9/5zG36mxckI58wFf7G1/efnOjNmatHc0FT5jHOn6xsC2BQwrdQ7HVT8LfjHz1+RVqcejUoWbRrbfVp5j5d9PVtB31D9POYHfgTCTm6+putqWvu2HqCgagcLa105whXwEXJDEcTKqKy21LUq11DT9O2xhCO5MiIkr7i+O0BRRQB6jwt27PT5h9VT2yM+UuioQBbca/dyHj+MIRF0uBn2g1CEJQU/9k="

        toRecipient = $("#recipient_input").val().trim()
        console.log "swyp goes to recip #{toRecipient}"
        @emit swypOut: {token: localSessionToken(), to: toRecipient, previewImageJPGBase64: base64PreviewImage, typeGroups: [pngFile, jpegFile]}
 
      $("#statusupdate_button").click ->
        makeStatusUpdate()
      
      d3.json "graph.json", (json) ->
        swypClient.initialize json
        
    
    localSessionToken = =>
      return $("#token_input").val()
   
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
      $('#swypMessages').append "<br /> @ #{@data.dateCreated} swypIn avail w.ID #{@data.id} from #{@data.swypSender} with types: #{@data.availableMIMETypes} <img src='#{@data.swypSender.userImageURL}' /> <img src='#{@data.previewImageURL}' />"
      $('#swypMessages').append "<input id= 'button_#{@data.id}', type= 'button', value='swyp in!'>"
      $("#button_#{@data.id}").bind 'click', =>
          makeSwypIn(@data.id)
      swypClient.addPending {objectID: @data.id, userName: @data.swypSender.userName, userImageURL: @data.swypSender.userImageURL, thumbnailURL: @data.previewImageURL}


    @on swypOutPending: ->
      $('#swypMessages').append "<br /> did swypOut @ #{@data.time} w.ID #{@data.id}"

    @on welcome: ->
      $('#swypMessages').append "Welcome to swyp,  #{@data.time}"
    
    @on unauthorized: ->
      $('#swypMessages').append "<br />You're currently not logged in. <a href='/login'>Login here</a>."
    
    @on updateGood: ->
      $('#swypMessages').append "<br />you updated successfully! Cool yo!"
    
    @on nearbyRefresh: ->
      $('#swypMessages').append "<br />received a nearby session update! w. nearby: #{JSON.stringify(@data.nearby)}"
      peers = @data.nearby
      graph = {nodes:[{userName:"",userImageURL:"", friend:true}], links:[]}
      i = 1
      for peer in peers
        graph.nodes.push({userName:peer.userName, userImageURL:peer.userImageURL, friend:false})
        graph.links.push({source:i, target:0})
        i += 1

      swypClient.setupBubbles graph


    @on updateRequest: ->
      $('#swypMessages').append "<br />update requested!"
      makeStatusUpdate()

    @on dataAvailable: ->
      $('#swypMessages').append "<img src='#{@data.contentURL}' alt='imgID#{@data.id} of type #{@data.contentMIME}'/>"
     
    @connect()
