# mocha -R nyan -w shorturlTestv1.coffee --compilers coffee:coffee-script shorturlTestv1.coffee
#73 objects are inserted/removed in this test
## this test SHOULD be non-distructive, at least that's what my unit tests have seemed to show me-- if anything else, please let me know ASAP on github!!


surl = require '../model/shorturl'
should = require("should")

suSecrets = require("./shorturlTestSecrets")

describe 'shorturl', =>
  generatedShortened = []
  before (done) =>
    #48-57,65-90,97-122 (base64-characters to intersect w. char-count-roll-up functionality)
    codes = []
    for i in ([48..57].concat([65..90]).concat([97..122]))
      codes.push String.fromCharCode(i)
    for code in codes
      surl.shorten suSecrets.validCodeRedirectPairs[0], suSecrets.codeLength, null, false, code, null, (err, shortURL) =>
        generatedShortened.push shortURL
    #set key-vals for validCodeRedirectPairs and customCodeRedirectPair
    ##pushes validCodeRedirectPairs' values back into exports of validCodeRedirectPairs
    for i in [0..suSecrets.validCodeRedirectPairs.length - 1]
      do (i) ->
        uri = suSecrets.validCodeRedirectPairs[i][1]
        surl.shorten uri, suSecrets.codeLength, null, false, null, null, (err, shortURL) =>
          generatedShortened.push shortURL
          code = shortURL.shortURICode
          suSecrets.validCodeRedirectPairs[i][0] = code
          if i == suSecrets.validCodeRedirectPairs.length - 1
            done()
 
  after (done) =>
    #console.log "removing a bunch of objs #{generatedShortened.length}"
    #73 objects are inserted/removed in this cycle
    for short in generatedShortened
      short.remove (err) =>
        if err?
          console.log "teardown err for short #{short}, err: #{err}"
    done()
  
  describe '#shorten', =>
    it 'should shorten unique (not in db) urls with unique short code', (done) ->
      surl.shorten suSecrets.validTestRedirectURI, suSecrets.codeLength, null, false, null, null, (err, shortURL) =>
        generatedShortened.push shortURL
        should.not.exist err
        shortURL.redirectURI.should.eql suSecrets.validTestRedirectURI
        should.exist shortURL.shortURICode
        done()

    it 'should shorten previously shortened urls with previous short code when reuse is true and previous code is not custom, regardless of min length', (done) ->
      codeRedirectPair = suSecrets.validCodeRedirectPairs[0]
      surl.shorten codeRedirectPair[1], suSecrets.codeLength, null, true, null, null, (err, shortURL) =>
        should.not.exist err
        should.exist shortURL
        shortURL.redirectURI.should.eql codeRedirectPair[1]
        shortURL.shortURICode.should.eql codeRedirectPair[0]
        done()

    it "should set creator user info when it's included", (done) ->
      surl.shorten suSecrets.validTestRedirectURI, suSecrets.codeLength, null, false, null, suSecrets.validUserInfo, (err, shortURL) =>
        should.not.exist err
        generatedShortened.push shortURL
        should.exist shortURL.creatorUserInfo
        shortURL.creatorUserInfo.should.eql suSecrets.validUserInfo
        done()

    it 'should return a url of min length 5 when no minlength is included', (done) ->
      surl.shorten suSecrets.validTestRedirectURI, null, null, false, null, null, (err, shortURL) =>
        should.not.exist err
        generatedShortened.push shortURL
        should.exist shortURL.shortURICode
        shortURL.shortURICode.length.should.be.above(4)
        done()
    it 'should shorten uris with custom code, yielding the same custom code as given', (done) ->
      surl.shorten suSecrets.customCodeRedirectPair[1], suSecrets.codeLength, null, false, suSecrets.customCodeRedirectPair[0], null, (err, shortURL) =>
        should.not.exist err
        generatedShortened.push shortURL
        shortURL.redirectURI.should.eql suSecrets.customCodeRedirectPair[1]
        shortURL.shortURICode.should.eql suSecrets.customCodeRedirectPair[0]
        done()

    it 'should shorten url with new short uri code when reuse is true and previous code is custom', (done) ->
      surl.shorten suSecrets.customCodeRedirectPair[1], suSecrets.codeLength, null, true, null, suSecrets.validUserInfo, (err, shortURL) =>
        should.not.exist err
        generatedShortened.push shortURL
        shortURL.redirectURI.should.eql suSecrets.customCodeRedirectPair[1]
        should.exist shortURL.shortURICode
        shortURL.shortURICode.should.not.eql suSecrets.customCodeRedirectPair[0]
        done()
    
    it 'should shorten previously shortened urls with new short code when reuse is false', (done) ->
      codeRedirectPair = suSecrets.validCodeRedirectPairs[0]
      surl.shorten codeRedirectPair[1], suSecrets.codeLength, null, false, null, null, (err, shortURL) =>
        should.not.exist err
        generatedShortened.push shortURL
        shortURL.redirectURI.should.eql codeRedirectPair[1]
        should.exist shortURL.shortURICode
        shortURL.shortURICode.should.not.eql codeRedirectPair[0]
        done()
    it 'should work well when in-domain url is shortened', (done) ->
      surl.shorten suSecrets.validTestRedirectURI, suSecrets.codeLength, suSecrets.domainTestSameDomain, false, null, null, (err, shortURL) =>
        should.not.exist err
        should.exist shortURL
        generatedShortened.push shortURL
        done()
    it 'should err when given an out-of domain url to shorten and domain is defined', (done) -> #where domain is url prefix. eg, http://offer.vc
      surl.shorten suSecrets.domainTestURI, suSecrets.codeLength, suSecrets.domainTestDifferentDomain, false, null, null, (err, shortURL) =>
        should.exist err
        should.not.exist shortURL
        done()
    it 'should err when given no url to shorten', (done) ->
      surl.shorten null, suSecrets.codeLength, null, false, null, null, (err, shortURL) =>
        should.exist err
        should.not.exist shortURL
        done()
    it 'should err when custom short code is given that intercepts existing short code', (done) ->
      surl.shorten suSecrets.validCodeRedirectPairs[0], suSecrets.codeLength, null, false,suSecrets.customCodeRedirectPair[0], null, (err, shortURL) =>
        should.exist err
        should.not.exist shortURL
        done()
    it 'should err when when customCode = prior custom code, and redirectURI = priorRedirectURI, when reuse == true', (done) =>
      surl.shorten suSecrets.customCodeRedirectPair[1], suSecrets.codeLength, null, false, suSecrets.customCodeRedirectPair[0], null, (err, shortURL) =>
        should.exist err
        should.not.exist shortURL
        done()
    it 'should err when when customCode = prior custom code, and redirectURI = priorRedirectURI, when reuse == false', (done) =>
      surl.shorten suSecrets.customCodeRedirectPair[1], suSecrets.codeLength,null, false, suSecrets.customCodeRedirectPair[0], null, (err, shortURL) =>
        should.exist err
        should.not.exist shortURL
        done()
    it 'should return short urls of minimum of specified length', (done) ->
      surl.shorten suSecrets.validTestRedirectURI, suSecrets.codeLength, null, false, null, null, (err, shortURL) =>
        should.not.exist err
        should.exist shortURL.shortURICode
        shortURL.shortURICode.length.should.be.above(suSecrets.codeLength - 1)
        generatedShortened.push shortURL
        done()
    it 'should return code of 1 character longer if random hash generations yields collisions for 3 generations in a row', (done) ->
      surl.shorten suSecrets.validTestRedirectURI, 1, null, false, null, null, (err, shortURL) =>
        should.not.exist err
        generatedShortened.push shortURL
        should.exist shortURL.shortURICode
        shortURL.shortURICode.length.should.be.above(1)
        done()

  describe '#retrieve', =>
    it 'should retrieve the correct url after just being set', (done) =>
      #first setup, then test
      codeRedirectPair = suSecrets.validCodeRedirectPairs[0]
      surl.retrieve codeRedirectPair[0], suSecrets.validUserInfo, (err, shortURL) =>
        should.not.exist err
        shortURL.redirectURI.should.eql codeRedirectPair[1]
        done()
    it 'should properly increment the retrieve count after retrieving', (done) =>
      surl.retrieve suSecrets.validCodeRedirectPairs[0][0], suSecrets.validUserInfo, (err, shortURL) =>
        should.not.exist err
        shortURL.redirectCount.should.be.above(0)
        surl.retrieve suSecrets.validCodeRedirectPairs[0][0], suSecrets.validUserInfo, (err, shortURL) =>
          should.not.exist err
          shortURL.redirectCount.should.be.above(1)
          done()
    it 'should properly include userInfo data after retreiving, when included', (done) =>
      surl.retrieve suSecrets.validCodeRedirectPairs[0][0], suSecrets.validUserInfo, (err, shortURL) =>
        should.not.exist err
        should.exist shortURL.redirects
        shortURL.redirects.length.should.be.above(0)
        should.exist shortURL.redirects[shortURL.redirects.length - 1].userInfo
        surl.retrieve suSecrets.validCodeRedirectPairs[0][0], suSecrets.validUserInfo, (err, shortURL) =>
          should.not.exist err
          should.exist shortURL.redirects
          shortURL.redirects.length.should.be.above(1)
          should.exist shortURL.redirects[shortURL.redirects.length - 1].userInfo
          done()
    it 'should properly reset last access date after retreiving', (done) ->
      surl.retrieve suSecrets.validCodeRedirectPairs[0][0], suSecrets.validUserInfo, (err, shortURL) =>
        should.not.exist err
        Math.abs((shortURL.modifiedDate.getTime()- new Date().getTime())).should.be.below(1000)
        done()
    it 'should return error when no url exists for code', (done) ->
      surl.retrieve null, suSecrets.validUserInfo, (err, shortURL) =>
        should.exist err
        done()
    it 'should be fine without userinfo passed', (done) ->
      surl.retrieve suSecrets.validCodeRedirectPairs[0][0], null, (err, shortURL) =>
        should.exist shortURL
        should.not.exist err
        done()

