Newsreader
=========

```bash
npm install
npm start
```

### web.coffee
The web server.

### fetcher.coffee
Fetches `skimfeed.com` main page content, get all the links, stores it to mongo.

### ranker.coffee
Assigns 10 news items to next page.

## How it works

1. Fetcher stores various news items from different sources to db
2. Ranker assignes page_id to items
3. Web page displays lowest page_id items
4. "Next" button
  * For items with lowest `page_id`, `page_id` is renamed to `viewed_page_id`.
5. Items that are clicked, will be marked as `clicked` in db
6. Items that are saved to Pocket, will be marked as `pocket` in db

## Planned

* Ranker
  * preferred keywords
  * classifier trained with `clicked` and `pocket` label ??
* Fetcher
  * filter sources
  * include it in web.coffee, run it time to time
* Web
  * login page
  * settings page
  * next : if no more pages to show, try running ranker
* DB
  * setup indexes
    * links should be uniq

* Package the whole thing as a single tar.gz, with Makefile or something
  * ./install.sh  will download necessary binaries, and npm start will run everything







