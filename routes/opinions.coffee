opinionsModel = require('../model/opinions')

exports.opinions = (req, res) ->
  opinionsModel.opinions (err, opinionList) =>
    @render opinions: {opinions: opinionList}
