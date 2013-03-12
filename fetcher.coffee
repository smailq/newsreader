# Mongoose
mongoose = require 'mongoose'
jsdom = require 'jsdom'
url = require 'url'


# Setup Mongoose
mongoose.connect('mongodb://localhost/test')

newsItemSchema = mongoose.Schema
  news_title: String
  news_url: String
  news_domain: String
  source_name: String
  source_url: String
  page_id: Number
  viewed_page_id: Number
  fetched_at: { type: Date, default: Date.now }

newsItemSchema.set('toObject')

NewsItem = mongoose.model('NewsItem', newsItemSchema)


jsdom.env "http://skimfeed.com/", ["http://code.jquery.com/jquery.js"],
  (err, window) ->

    parsed_links = []

    boxes = window.$("div.boxes")

    for box in boxes

      source = window.$("span.boxtitles a[target='_blank']", box)

      if not source?
        continue

      source_name = source.text()
      source_url = source.attr('href')

      links = window.$("ul li a[target='_blank']", box)

      if not links?
        continue

      for link in links
        href = link.href
        parsed_url = url.parse(href, true)
        real_url_parsed = url.parse(parsed_url.query.u)

        if not link.title? or not parsed_url.query.u?
          continue

        parsed_links.push
          news_title: link.title
          news_url: parsed_url.query.u
          news_domain: real_url_parsed.hostname
          source_name: source_name
          source_url: source_url
          fetched_at: Date.now()


    NewsItem.collection.insert parsed_links, {"safe":true}, (err) ->

      console.log err if err

      mongoose.disconnect()
      window.close()  
