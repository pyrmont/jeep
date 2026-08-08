(import ../info)
(import ../util)

(def- helps
  {:kvs
   `Keys and values to set. Keys must be keywords (e.g. :author). A value of
   nil removes the key.`
   :about
   `Edits top-level key-value pairs in the bundle's info file.`
   :help
   `Edit top-level metadata in the current bundle.`})

(def config {:rules [:kvs {:splat? true
                           :req?   true
                           :help   (helps :kvs)}
                     "----"]
             :info {:about (helps :about)}
             :help (helps :help)})

(var- changed? false)

(defn- edit-kvs
  [jdn meta pairs]
  # the info file is invalid without a string name, so it is checked before any
  # pair is applied
  (each [k v] pairs
    (when (= :name k)
      (assert (not (nil? v)) "cannot remove the :name key")
      (assert (string? v) "the :name key must be a string")
      (assert (not (empty? v)) "the :name key must not be empty")))
  (var result jdn)
  (each [k v] pairs
    (if (nil? v)
      # a nil value removes the key
      (if (has-key? meta k)
        (do
          (set changed? true)
          (print "removing " (describe k) "...")
          (set result (info/remove result [k])))
        (print "skipping " (describe k) ", key not found"))
      # setting a key to its current value leaves the info file alone
      (do
        (def before (info/render result))
        (set result (info/put result [k] v))
        (unless (= before (info/render result))
          (set changed? true)
          (print "setting " (describe k) "...")))))
  result)

(defn run
  [args &opt jeep-config]
  jeep-config # TODO: Add support for configuring via existing file
  (set changed? false)
  (def kvs (get-in args [:sub :params :kvs] []))
  (def pairs (util/to-pairs kvs))
  (def info (util/load-info))
  (assert info "no info.jdn file found")
  (def [ok? parsed]
    (protect
      (do
        (def jdn (info/parse info))
        [jdn (info/value jdn)])))
  (assert ok? "info.jdn could not be parsed")
  (def [jdn meta] parsed)
  (assert (get meta :name) "info.jdn file must contain the :name key")
  (def edited (edit-kvs jdn meta pairs))
  (util/save-info (info/render edited))
  (if changed?
    (print "Metadata changed.")
    (print "No metadata changed.")))
