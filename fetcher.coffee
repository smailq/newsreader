jsdom = require 'jsdom'

jsdom.env "http://skimfeed.com/", ["http://code.jquery.com/jquery.js"],
  (err, window) ->
    console.log "there are ", window.$("a").length, "links!"
