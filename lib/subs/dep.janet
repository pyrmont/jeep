(import ../info)
(import ../install)
(import ../util)

(def- helps
  {:deps
   `Deps to add or remove. Dependencies can be provided as short names, URLs or
   JDN structs/tables.`
   :remove
   `Remove the deps from the bundle.`
   :vendor
   `Update the deps under <dir> associated with the ':vendored' key.`
   :about
   `Adds or removes dependency information in the bundle's info file.`
   :help
   `Add or remove dependency information in the current bundle.`})

(def config {:rules [:deps {:splat? true
                            :req?   true
                            :help   (helps :deps)}
                     "--remove" {:kind  :flag
                                 :short "r"
                                 :help  (helps :remove)}
                     "--vendor" {:kind  :single
                                 :short "v"
                                 :proxy "dir"
                                 :help  (helps :vendor)}
                     "----"]
             :info {:about (helps :about)}
             :help (helps :help)})

(def- peg '(* :w+ "://"))

(defn- remote-name
  [url]
  (def temp-dir "tmp")
  (defer (util/rmrf temp-dir)
    (os/mkdir temp-dir)
    (def devnull (util/devnull))
    (def stdio {:out devnull :err devnull})
    (util/exec :git stdio "clone" "--depth" "1" url temp-dir)
    (get (util/load-meta "tmp") :name)))

(defn- add-deps
  [jdn meta group deps]
  (def to-add @[])
  (each d deps
    (cond
      (util/url? d)
      (do
        (def url (if (peg/match peg d) d (string "https://" d)))
        (def name (remote-name url))
        (assert name (string "dependency at " url " is missing info.jdn file with :name key"))
        (array/push to-add {:name name :url url}))
      (string? d)
      (array/push to-add d))
    (def resolved (array/peek to-add))
    (if (find (partial = resolved) (get-in meta group []))
      (array/pop to-add)))
  (each d to-add
    (print "adding " (if (dictionary? d) (get d :name) d) "...")
    (info/add-to jdn group d))
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
      (string? d)
      (array/push to-rem d)))
  (each d to-rem
    (print "removing " d "...")
    (info/rem-from jdn group d))
  jdn)

(defn run
  [args &opt jeep-config]
  (def opts (get-in args [:sub :opts] {}))
  (def deps (get-in args [:sub :params :deps] []))
  (def group (if-let [dir (get opts "vendor")]
               [:vendored dir]
               [:dependencies]))
  (def remove? (get opts "remove"))
  (def info (util/load-info))
  (assert info "no info.jdn file found")
  (def meta (parse info))
  (assert (get meta :name) "info.jdn file must contain the :name key")
  (def jdn (info/jdn-str->jdn-arr info))
  (if remove?
    (rem-deps jdn meta group deps)
    (add-deps jdn meta group deps))
  (util/save-info (info/jdn-arr->jdn-str jdn))
  (print "Dependencies updated."))
