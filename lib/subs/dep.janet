(import ../info)
(import ../install)
(import ../util)

(def- helps
  {:autotag
   `Automatically add to each dep the tag associated with the current commit.`
   :deps
   `Deps to add or remove. Each dep can be a short name, URL or JDN
   struct/table.`
   :remove
   `Remove the deps from the bundle.`
   :update
   `Update the deps in the bundle.`
   :vendor
   `Change dependencies under the :vendored keyword.`
   :about
   `Adds, updates or removes dependency information in the bundle's info file.`
   :help
   `Add, update or remove dependency information in the current bundle.`})

(def config {:rules [:deps {:splat? true
                            :req?   true
                            :help   (helps :deps)}
                     "--autotag" {:kind  :flag
                                  :short "a"
                                  :help  (helps :autotag)}
                     "--remove" {:kind  :flag
                                 :short "r"
                                 :help  (helps :remove)}
                     "--update" {:kind  :flag
                                 :short "u"
                                 :help  (helps :update)}
                     "--vendor" {:kind  :flag
                                 :short "v"
                                 :help  (helps :vendor)}
                     "----"]
             :info {:about (helps :about)}
             :help (helps :help)})

(def- peg '(* :w+ "://"))
(var- changed? false)

(defn- to-dirname
  [url]
  (def b @"")
  (var i 0)
  (while (def c (get url i))
    (def us (chr "_"))
    (buffer/push b
                 (case c
                   (chr ":") us
                   (chr "/") us
                   (chr "~") us
                   (chr "?") us
                   c))
    (++ i))
  (string b))

(defn- fetch-repo
  [url]
  (def tmp (util/tmp-dir))
  (def dir (string tmp util/sep (to-dirname url)))
  (unless (os/mkdir dir)
    (break dir))
  (util/exec :git nil "clone" "--depth" "1" url dir)
  dir)

(defn- fetch-name
  [url]
  (def dir (fetch-repo url))
  (get (util/load-meta dir) :name))

(defn- fetch-tag
  [url]
  (if (nil? url) (break))
  (def dir (fetch-repo url))
  (def [r w] (os/pipe))
  (util/exec :git {:out w} "-C" dir "rev-parse" "HEAD")
  (:close w)
  (string/trim (ev/read r :all)))

(defn- add-deps
  [jdn meta group deps &opt autotag?]
  (def listed (get-in meta group []))
  (def to-add @[])
  (each d-str deps
    (def [ok? res] (protect (parse d-str)))
    (def d (if (and ok? (dictionary? res)) res d-str))
    (cond
      (dictionary? d)
      (do
        (assertf (get d :name) "dependency %n requires :name" d)
        (assertf (get d :url) "dependency %n requires :url" d)
        (def tag (if autotag? (fetch-tag (get d :url))))
        (array/push to-add (struct :tag tag ;(pairs d))))
      (util/url? d)
      (do
        (def url (if (peg/match peg d) d (string "https://" d)))
        (def name (fetch-name url))
        (assertf name "dependency %s is missing info.jdn file with :name key" url)
        (array/push to-add {:name name :url url :tag (if autotag? (fetch-tag url))}))
      # default
      (array/push to-add d))
    (def new (array/peek to-add))
    (def new-name (if (dictionary? new) (get new :name) new))
    (def pos (find-index
               (fn :finder [curr]
                 (def curr-name (if (dictionary? curr) (get curr :name) curr))
                 (= new-name curr-name))
               listed))
    (when pos
      (print "skipping " new-name ", use --update to update existing dependencies")
      (array/pop to-add)))
  (each d to-add
    (set changed? true)
    (print "adding " (if (dictionary? d) (get d :name) d) "...")
    (info/add-to jdn group [d]))
  jdn)

(defn- bundle-from-url
  [listed url]
  (var res nil)
  (each d listed
    (when (and (dictionary? d)
               (= url (get d :url)))
      (set res d)
      (break)))
  (if (nil? res)
    (error (string "no dependency with URL " url))
    res))

(defn- rem-deps
  [jdn meta group deps]
  (def listed (get-in meta group []))
  (if (empty? listed) (break))
  (def to-rem @[])
  (each d deps
    (cond
      (util/url? d)
      (do
        (def url (if (peg/match peg d) d (string "https://" d)))
        (def name (get (bundle-from-url listed url) :name))
        (array/push to-rem name))
      # default
      (array/push to-rem d)))
  (each d to-rem
    (set changed? true)
    (print "removing " (if (dictionary? d) (get d :name) d) "...")
    (info/rem-from jdn group :where (fn [x] (or (= x d)
                                                (= (get x :name) d)))))
  jdn)

(defn- upd-deps
  [jdn meta group deps &opt autotag?]
  (def listed (get-in meta group []))
  (def to-upd @[])
  (each d-str deps
    (def [ok? res] (protect (parse d-str)))
    (def d
      (cond
        (and ok? (dictionary? res))
        (do
          (assertf (get res :name) "dependency %n requires :name" res)
          (if (struct? res) (struct/to-table res) res))
        (util/url? d-str)
        (do
          (def url (if (peg/match peg d-str) d-str (string "https://" d-str)))
          (def name (fetch-name url))
          (assertf name "dependency %s is missing info.jdn file with :name key" url)
          @{:name name :url url})
        # default
        @{:name d-str}))
    (def name (get d :name))
    (def curr (find
                (fn [x]
                  (if (dictionary? x)
                    (= name (get x :name))
                    (= name x)))
                listed))
    (cond
      # dependency not listed
      (nil? curr)
      (print "skipping " name ", add as dependency first")
      # listed dependency is struct/table
      (dictionary? curr)
      (array/push to-upd [d :assoc (or (get d :url) (get curr :url))])
      # both are shortnames
      (nil? (get d :url))
      (print "skipping " name ", cannot update shortname dependency")
      # default
      (array/push to-upd [d :swap (get d :url)])))
  (each [d action url] to-upd
    (assertf url "cannot update dependency %s without :url set" (get d :name))
    (set changed? true)
    (def name (get d :name))
    (print "updating " name "...")
    (when autotag?
      (put d :tag (fetch-tag url)))
    (defn pred [x]
      (if (dictionary? x)
        (= name (get x :name))
        (= name x)))
    (case action
      :assoc
      (do
        (def keyvals @[])
        (each [k v] (sort (pairs d))
          (array/push keyvals k v))
        (info/upd-in jdn group :where pred :add keyvals))
      :swap
      (info/upd-in jdn group :where pred :to (table/to-struct d))))
  jdn)

(defn run
  [args &opt jeep-config]
  (set changed? false)
  (def opts (get-in args [:sub :opts] {}))
  (def deps (get-in args [:sub :params :deps] []))
  (def group (if (get opts "vendor") [:vendored] [:dependencies]))
  (def autotag? (get opts "autotag"))
  (def remove? (get opts "remove"))
  (def update? (get opts "update"))
  (assert (not (and remove? update?)) "cannot set --remove and --update")
  (def info (util/load-info))
  (assert info "no info.jdn file found")
  (def [ok? meta] (protect (parse info)))
  (assert ok? "info.jdn could not be parsed")
  (assert (get meta :name) "info.jdn file must contain the :name key")
  (def jdn (info/jdn-str->jdn-arr info))
  (def cwd (os/cwd))
  (cond
    # remove
    remove?
    (rem-deps jdn meta group deps)
    # update
    update?
    (defer
     (util/cleanup cwd)
     (upd-deps jdn meta group deps autotag?))
    # default
    (defer
      (util/cleanup cwd)
      (add-deps jdn meta group deps autotag?)))
  (util/save-info (info/jdn-arr->jdn-str jdn))
  (if changed?
    (print "Dependencies changed.")
    (print "No dependencies changed.")))
