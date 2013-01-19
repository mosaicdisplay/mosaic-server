#test secrets for shorturl

#once inserted, these pairs have their shortcode changed
exports.validCodeRedirectPairs = [['12345', 'http://offer.vc/urltestredirect'], ['23451', 'http://offer.vc/urltestredirect2']]

exports.customCodeRedirectPair = ['customCodeTest','http://offer.vc/customURITest']

exports.validTestRedirectURI = 'http://offer.vc/urltestredirect3'
exports.domainTestDifferentDomain = 'http://wrong.domain/'
exports.domainTestSameDomain = 'http://offer.vc/'

exports.codeLength = 4
exports.validUserInfo = {userName: 'testr', ip: '192.222222'}
