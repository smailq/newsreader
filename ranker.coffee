# Ranks news items into pages

# Mongoose
mongoose = require 'mongoose'
# Async
async = require 'async'

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

async.parallel([
  (cb) ->
    # Find largest page_id
    NewsItem.findOne({"page_id": { "$exists": true } }).sort("-page_id").exec( (err, newsItem) ->
      if not newsItem? or err
        return cb(null, null) 
      else
        cb null, newsItem.page_id
    )
  ,
  (cb) ->
    # Find largest viewed_page_id
    NewsItem.findOne({"viewed_page_id": { "$exists": true } }).sort("-viewed_page_id").exec( (err, newsItem) ->
      if not newsItem? or err
        return cb(null, null) 
      else
        cb null, newsItem.page_id
    )
  ],
  
  (err, results) ->
    return mongoose.disconnect() if err

    # Set largest new page_id
    new_page_id = 0

    if results[0]?
      new_page_id = results[0] + 1
    else if results[1]?
      new_page_id = results[1] + 1

    # Just mark any 10 items
    NewsItem.find({"page_id": {"$exists":false}, "viewed_page_id" : {"$exists" : false } } ).sort("-fetched_at").limit(10).exec( (err, newsItems) ->

      return mongoose.disconnect() if not newsItems? or err

      idlist = []

      for newsItem in newsItems
        idlist.push(newsItem._id)

      NewsItem.update  { "_id" : { "$in": idlist } }, { "$set" : { "page_id": new_page_id } }, {"multi":true}, (err) ->
        console.log err if err      
        mongoose.disconnect()

    )
)
