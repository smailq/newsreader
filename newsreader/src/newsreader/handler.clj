(ns newsreader.handler
  (:use compojure.core newsreader.views)
  (:require [compojure.handler :as handler]
            [compojure.route :as route]))


(defroutes app-routes
  (GET "/" [] (newslist-page))
  (route/resources "/")
  (route/not-found "Not Found"))

(def app
  (handler/site app-routes))

