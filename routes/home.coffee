exports.home = (req, res) ->
  right = 'thingsRight'
  left = 'thingsLeft'
  backgrounds = ["/img/mugshots/large/mexicali.jpg", "/img/mugshots/large/area4-torso.jpg","/img/mugshots/large/brazil-olinda.jpg","/img/mugshots/large/philly-walkway.jpg"]
  backgroundWeights = [.5,.2,.2,.1]
  interfaceSides = [right,left,left, right]
 
  background = "/img/mugshots/large/mexicali.jpg"
  side = "thingsRight"

  weight = Math.random()
  sumWeight = 0
  for i in [0..backgrounds.length]
    sumWeight = sumWeight + backgroundWeights[i]
    if weight < sumWeight
      background = backgrounds[i]
      side = interfaceSides[i]
      break
  @render index: {backgroundImage:background, sideClass: side}
