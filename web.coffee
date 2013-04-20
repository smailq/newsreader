# Web framework
express = require 'express'
# Templating language
jade = require 'jade'
# Dynamic CSS
stylus = require 'stylus'
# String validation
validator = require 'validator'
# Misc. utils
_ = require 'underscore'
# Logger
winston = require 'winston'
# Configuration management
nconf = require 'nconf'

# Async
async = require 'async'

jsdom = require 'jsdom'
url = require 'url'
pg = require 'pg'

uuid = require 'node-uuid'

pg_address = 'pg://web:web@localhost/newsreader'

# Configure 'nconf'
nconf.argv().env()
# Environment specific configs
if process.env.NODE_ENV? and process.env.NODE_ENV != ""
  nconf.add 'user',
    type:'file'
    file: './configs/' + process.env.NODE_ENV + '.json'
# Default config
nconf.add 'global',
  type:'file'
  file: './configs/defaults.json'

# Set winston to write logs to file if 'logFile' is defined
if nconf.get('logFile')?
  winston.add winston.transports.File, { filename: nconf.get('logFile') }
  winston.remove winston.transports.Console


# Setup express
app = express()
# Don't forget the favicons!
app.use express.favicon('static/favicon.ico')
# If cookies are used, encrypt them!
app.use express.cookieParser(nconf.get('cookieSecret'))
# Session vars are nice, but personally not a fan.
# Try to use Redis, memcached, or other independant solutions.
#app.use express.cookieSession()
# Parse body
app.use express.bodyParser()
# asset pipeline
app.use require('connect-assets')()
# Static files (on prod, have web servers serve these)
app.use '/static', express.static __dirname + '/static'
# Setup jade template views
app.set 'views', __dirname + '/views'
app.set 'view engine', 'jade'
app.set 'view options', layout: false

# Set locals for global template context
app.use (req,res,next) ->

  # Set defaults
  res.locals.env = process.env.NODE_ENV
  res.locals.news_links = []
  res.locals.new_count = '?'
  res.locals.archived_count = '?'
  res.locals.clicked_count = '?'
  res.locals.saved_count = '?'


  pg.connect pg_address, (err, client, done) ->

    return next err if err?


    client.query(
      "SELECT count(CASE WHEN flags ? 'archived' THEN null ELSE 1 END) AS new_count, count(CASE WHEN flags ? 'archived' THEN 1 ELSE null END) AS arch_count,count(CASE WHEN flags ? 'clicked' THEN 1 ELSE null END) AS click_count FROM items",
      (err, result) ->
        return next err if err?

        res.locals.new_count = result.rows[0]['new_count']
        res.locals.archived_count = result.rows[0]['arch_count']
        res.locals.clicked_count = result.rows[0]['click_count']
        done()
        next()
    )


# Landing page
app.get '/', (req, res, next) ->

  pg.connect pg_address, (err, client, done) ->

    return next err if err?

    client.query(
      "SELECT * FROM items WHERE ((CASE WHEN flags IS NULL THEN ''::hstore ELSE flags END) ? 'clicked') is false AND ((CASE WHEN flags IS NULL THEN ''::hstore ELSE flags END) ? 'archived') is false AND page_num IN (SELECT page_num FROM items WHERE page_num IS NOT NULL ORDER BY page_num DESC LIMIT 1)",
      (err, result) ->
        done()

        return next err if err?
        
        res.locals.news_links = result.rows


        res.render 'pages/landing'
        
    )

app.get '/archived', (req, res, next) ->
  
  res.locals.filter_name = 'archived'
  res.render 'pages/filtered'

app.get '/clicked', (req, res, next) ->

  pg.connect pg_address, (err, client, done) ->

    return next err if err?

    client.query(
      "SELECT * FROM items WHERE flags ? 'clicked' LIMIT 50",
      (err, result) ->
        
        console.log result.rows
        return next err if err?
        
        res.locals.news_links = result.rows
        res.locals.filter_name = 'clicked'
        res.render 'pages/filtered'

        done()
    )

app.get '/saved', (req, res, next) ->
  
  res.locals.filter_name = 'saved'
  res.render 'pages/filtered'

app.get '/graphs', (req, res, next) ->
  res.render 'pages/graphs'



# Mark top pages as read
app.get '/next', (req, res, next) ->

  pg.connect pg_address, (err, client, done) ->

    return next err if err?

    client.query(
      "SELECT page_num FROM items WHERE page_num IS NOT NULL ORDER BY page_num DESC LIMIT 1",
      (err, result) ->

        return next err if err?

        page_num = 1
        
        if result.rowCount == 1
          page_num = result.rows[0]['page_num'] + 1

        client.query(
          "UPDATE items SET page_num = $1 WHERE id IN (SELECT id FROM items WHERE page_num IS NULL ORDER BY rank DESC LIMIT 9)",
          [ page_num ],
          (err, result) ->
            return next err if err?

            client.query(
              "UPDATE items SET flags = (CASE WHEN flags IS NULL THEN '' ELSE flags END) || hstore('archived','1') WHERE page_num < $1",
              [ page_num ],
              (err, result) ->
                return next err if err?




                res.redirect '/'
                done()
            )
        )
    )


app.get '/fetch', (req, res, next) ->

  pg.connect pg_address, (err, client, done) ->

    client.query(
      "UPDATE items SET page_num = -1 WHERE id IN (SELECT id FROM items WHERE page_num IS NULL AND fetched_at < now() - interval '12 hours')",
      (err, result) ->
    )

    return next err if err?
    
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

          
          client.query(
            "INSERT INTO items (title, url, domain, id) VALUES ($1, $2, $3, $4);",
            [ link.title, parsed_url.query.u, real_url_parsed.hostname, uuid.v4() ],
            (err) ->
              # ignore err
          )

          

          #a.save()

      res.redirect '/'
      done()


app.get '/click/:id', (req, res, next) ->
  pg.connect pg_address, (err, client, done) ->

    return next err if err?

    client.query(
      "SELECT url FROM items WHERE id = $1 LIMIT 1",
      [ req.param('id') ]
      (err, result) ->

        return next err if err?

        if result.rowCount == 1
          res.redirect result.rows[0]['url']
        else
          res.status 404
          res.render '404'

        client.query(
          "UPDATE items SET flags = (CASE WHEN flags IS NULL THEN '' ELSE flags END) || hstore('clicked','1') WHERE id = $1"
          [ req.param('id') ]
          (err, result) ->

            done()

            # return next err if err?
        )
    )


app.get '/options', (req, res, next) ->
  res.render 'pages/options'

# Demonstrate unhandled exceptions
app.get '/throw', (req, res, next) ->
  throw new Error('handles exceptions!')

# Demonstrate next(err)
app.get '/next_err', (req, res, next) ->
  err = new Error('something happened')
  err.extra_data = 
    foo: 'bar'
    bar: 'foo'
  err.status = 503
  next err

# Not found if reached here
app.use (req, res, next) ->
  res.status 404
  res.render '404'

# Error Handling
app.use (err, req, res, next) ->
  res.status(err.status || 500)
  res.render '500'
  # Log stuff
  winston.error err.message, {"module": "web", "error": err, "headers": req.headers}

# Start Web Server
app.listen nconf.get('port'), ->
  winston.info "Server is up and running!", { "port" : nconf.get('port') }
