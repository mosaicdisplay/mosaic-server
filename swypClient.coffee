@include = ->
  @client '/swyp.js': ->
    $('document').ready ->
      $('#logout').click (e)->
        e.preventDefault()
        FB.logout (res)->
          console.log res
    $ =>
      $('#swypOut_button').click (e) =>
       pngFileType = {
          fileURL : "http://swyp.us/guide/setupPhotos/setup1.png"
          fileMIME : "image/png"
        }

       jpegFileType = {
          fileURL : "http://fluid.media.mit.edu/people/natan/media/swyp/swyp.jpg"
          fileMIME : "image/jpeg"
        }

        @emit swypOut: {token: $("#token_input").val(), previewImage: "NONE!", fileTypes: [pngFileType, jpegFileType]}
 
      $("#statusupdate_button").click ->
        makeStatusUpdate()

    makeStatusUpdate = =>
      @emit statusUpdate: {token: $("#token_input").val(), location: [44.680997,10.317557]}
 
    @on swypInAvailable: ->
      console.log "swyp in available"
      $('body').append "<br /> @ #{@data.dateCreated} swypIn avail w.ID #{@data._id} from #{@data.swypOuter} with types: #{@data.fileTypes}"

    @on swypOutPending: ->
      $('body').append "<br /> did swypOut @ #{@data.time} w.ID #{@data._id}"

    @on welcome: ->
      $('body').append "Hey Ethan, socket.io says the time!: #{@data.time}"
    
    @on unauthorized: ->
      $('body').append "<br />yo token is unauthorized, fo!! try tokens _alex _al _a"
    
    @on updateGood: ->
      $('body').append "<br />you updated successfully! Cool yo!"
    
    @on nearbyRefresh: ->
      $('body').append "<br />received a nearby session update! w. nearby: #{JSON.stringify(@data.nearby)}"

    @on updateRequest: ->
      $('body').append "<br />update requested!"
      makeStatusUpdate()
     
    @connect()
