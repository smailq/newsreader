import requests
import urllib2
from bs4 import BeautifulSoup
import datetime


r = requests.get('http://skimfeed.com')

if r.status_code != 200:
  exit(0)

soup = BeautifulSoup(r.text, from_encoding=r.encoding)

items = []

for box in soup.find_all("div", class_="boxes"):

  if box.h3.span == None:
    continue

  for item in box.find_all("a"):
    if item.get('href') == None:
      continue

    def url_filter(x):
      return x.startswith('http')

    match = filter(url_filter, urllib2.unquote(item.get('href')).split('='))

    if len(match) <= 0:
      continue

    items.append({
      'title': item.get('title'),
      'url': match.pop(),
      'source': box.h3.span.a.string,
      'source_url': box.h3.span.a.get('href'),
      'fetched_at': datetime.datetime.utcnow()
    })


from pymongo import MongoClient

connection = MongoClient()
db = connection.test
collection = db.newsitems

collection.insert(items)
