(import ../info)
(import ../util)

(def- helps
  {:kvs
   `Key-value pairs to add, update or remove. Keys should be keywords (e.g., :author).
   When adding or updating, pairs should be specified as key value key value ...`
   :remove
   `Remove the specified keys from the bundle.`
   :update
   `Update the specified keys in the bundle.`
   :about
   `Adds, updates or removes top-level key-value pairs in the bundle's info file.`
   :help
   `Add, update or remove top-level metadata in the current bundle.`})

(def config {:rules [:kvs {:splat? true
                           :req?   true
                           :help   (helps :kvs)}
                    "--remove" {:kind  :flag
                                :short "r"
                                :help  (helps :remove)}
                    "--update" {:kind  :flag
                                :short "u"
                                :help  (helps :update)}
                    "----"]
            :info {:about (helps :about)}
            :help (helps :help)})

(var- changed? false)

(defn- add-kvs
  [jdn meta keyvals]
  (assertf (zero? (% (length keyvals) 2)) "expected even number of parameters, provided with %n" keyvals)
  (def to-add @[])
  (each [k-str v-str] (partition 2 keyvals)
    (def [k-ok? k-res] (protect (parse k-str)))
    (def k (if (and k-ok? (not (symbol? k-res))) k-res k-str))
    (assert (or (keyword? k) (string? k)) "key must be keyword or string")
    (def [v-ok? v-res] (protect (parse v-str)))
    (def v (if (and v-ok? (not (symbol? v-res))) v-res v-str))
    (if (get meta k)
      (print "skipping " (describe k) ", use --update to update existing keys")
      (array/push to-add [k v])))
  (each [k v] to-add
    (set changed? true)
    (print "adding " k "...")
    (info/add-to jdn [k] v))
  jdn)

(defn- rem-kvs
  [jdn meta ks]
  (def to-rem @[])
  (each k-str ks
    (def [k-ok? k-res] (protect (parse k-str)))
    (def k (if (and k-ok? (not (symbol? k-res))) k-res k-str))
    (if (get meta k)
      (array/push to-rem k)
      (print "skipping " (describe k) ", key not found")))
  (each k to-rem
    (set changed? true)
    (print "removing " (describe k) "...")
    (info/rem-from jdn [k]))
  jdn)

(defn- upd-kvs
  [jdn meta keyvals]
  (assertf (zero? (% (length keyvals) 2)) "expected even number of parameters, provided with %n" keyvals)
  (def to-upd @[])
  (each [k-str v-str] (partition 2 keyvals)
    (def [k-ok? k-res] (protect (parse k-str)))
    (def k (if (and k-ok? (not (symbol? k-res))) k-res k-str))
    (assert (or (keyword? k) (string? k)) "key must be keyword or string")
    (def [v-ok? v-res] (protect (parse v-str)))
    (def v (if (and v-ok? (not (symbol? v-res))) v-res v-str))
    (if (get meta k)
      (array/push to-upd [k v])
      (print "skipping " (describe k) ", add as key first")))
  (each [k v] to-upd
    (set changed? true)
    (print "updating " (describe k) "...")
    (info/upd-in jdn [k] :to v))
  jdn)

(defn run
  [args &opt jeep-config]
  (set changed? false)
  (def opts (get-in args [:sub :opts] {}))
  (def keyvals (get-in args [:sub :params :kvs] []))
  (def remove? (get opts "remove"))
  (def update? (get opts "update"))
  (assert (not (and remove? update?)) "cannot set --remove and --update")
  (def info (util/load-info))
  (assert info "no info.jdn file found")
  (def [ok? meta] (protect (parse info)))
  (assert ok? "info.jdn could not be parsed")
  (assert (get meta :name) "info.jdn file must contain the :name key")
  (def jdn (info/jdn-str->jdn-arr info))
  (cond
    # remove
    remove?
    (rem-kvs jdn meta keyvals)
    # update
    update?
    (upd-kvs jdn meta keyvals)
    # default
    (add-kvs jdn meta keyvals))
  (util/save-info (info/jdn-arr->jdn-str jdn))
  (if changed?
    (print "Metadata changed.")
    (print "No metadata changed.")))
