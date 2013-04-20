(ns newsreader.views
  (:use [hiccup core page]))


(defn topmenu-item-template [i-name i-value]
  (list [:a {:id i-name :href (str "/" i-name) } (str i-value (first i-name))] [:span.divider " / "]))


;(prn (for [[k v] {:asdf 3 :jio 4}] (topmenu-item-template (name k) v)))


(defn topmenu-template [counters]
  [:div.container-fluid
   [:div.masthead
    [:ul.nav.nav-pills.pull-right
     [:li [:a {:href "/options"} [:i.icon-cogs.icon-large]]]]]
    [:h3
     [:a {:href "/" :style "text-decoration:none;"} "NR"]
     [:small {:style "color:#444;padding-left:20px;"}      
      (for [[k v] counters] (topmenu-item-template (name k) v))]]])



(defn layout-template [content]
  (html5
     [:head
       [:title "NewsReader"]
       (include-css
          "/libs/twitter-bootstrap/2.3.1/css/bootstrap.css"
          "/libs/font-awesome/css/font-awesome.css")]
     [:body (topmenu-template {:archived 4 :next 3}) content]))


(defn newslist-page []
  (layout-template "something"))