#test secrets for shorturl

#once inserted, these pairs have their shortcode changed

exports.validIOIDs = ['10580437041611548230', '10580437041611548231','10580437041611548232','10580437041611548233']

exports.validIOIDDestroyTest = '10680437041611548234'

exports.validIODisaffiliateID = '10680437041611548235'


exports.validIOIDsForAGroup = ['10680437041611548230','10680437041611548231','10680437041611548232']

exports.validSwipeOutForSIOID = (id) ->
  return {sessionID: id, screenSize:{width: 320, height: 548}, swypPoint: {x: 320, y: 200}, direction: "out"}

exports.validSwipeInForSIOID = (id) ->
  return {sessionID: id, screenSize:{width: 768, height: 1024}, swypPoint: {x: 0, y: 500}, direction: "in"}
