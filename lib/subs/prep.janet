(import ../install)
(import ../util)

(def- helps
  {:profile
   `The profile to use. Valid choices are 'system', 'build' and 'vendor'.`
   :force-deps
   `Force installation of dependencies.`
   :no-deps
   `Skip installation of dependencies.`
   :about
   `Prepares the bundle for a given profile by installing dependencies and
   running the optional prep hook. For more information, see jeep-prep(1).`
   :help
   `Prepare dependencies for a given profile for the current bundle.`})

(def config
  {:rules [:profile       {:default "system"
                           :help (helps :profile)}
           "--force-deps" {:kind  :flag
                           :short "f"
                           :help (helps :force-deps)}
           "--no-deps"    {:kind :flag
                           :short "D"
                           :help (helps :no-deps)}
           "----"]
   :info {:about (get helps :about)}
   :help (get helps :help)})

(def- bundle-dir "bundle")
(def- this-file (os/realpath (dyn :current-file)))

(defn- vendor-deps-legacy
  [dirs-deps &named force-deps?]
  (def msg (string "warning: use of %ss with :vendored is deprecated, "
                   "refer to the man page for more information"))
  (printf msg (string (type dirs-deps)))
  (each [dir deps] (pairs dirs-deps)
    (each d deps
      (if (has-key? d :files)
        (util/fetch-dep d dir)
        (install/install-to d dir :force-update force-deps?)))))

(defn- vendor-deps
  [deps &named force-deps?]
  (each d deps
    (if (or (has-key? d :paths)
            (has-key? d :files))
      (util/fetch-dep d)
      (do
        (def dir (get d :prefix "."))
        (install/install-to d dir :force-deps? force-deps?)))))

(defn- install-build
  [info &named force-deps?]
  (def essentials
    ["build-rules.janet"
     "cc.janet"
     "cjanet.janet"
     "declare-cc.janet"
     "path.janet"
     "pm-config.janet"
     "sh.janet"
     "stream.janet"])
  (def spork-dir
    (string
      (if (string/has-prefix? (dyn :syspath) this-file)
        (string (dyn :syspath) util/sep "jeep")
        (string/slice this-file 0 -21))
      util/sep "deps" util/sep "spork"))
  (os/mkdir bundle-dir)
  (os/mkdir (string bundle-dir util/sep "spork"))
  (print "vendoring essential build files into " bundle-dir)
  (def from-licence (string spork-dir util/sep "LICENSE"))
  (def to-licence (string bundle-dir util/sep "spork" util/sep "LICENSE"))
  (print "  copying LICENSE to " bundle-dir util/sep "spork" util/sep "LICENSE")
  (util/copy from-licence to-licence)
  (each f essentials
    (def from (string spork-dir util/sep f))
    (def to (string bundle-dir util/sep "spork" util/sep f))
    (print "  copying " f " to " to)
    (util/copy from to)))

(defn- install-system
  [info &named force-deps?]
  (def system-deps (get info :dependencies []))
  (each d system-deps
    (install/install d :force-update force-deps?)))

(defn- install-vendor
  [info &named force-deps?]
  (def vendored (get info :vendored))
  (assert (and vendored (not (empty? vendored)))
          "no vendored dependencies in info.jdn")
  (def vendor-f (if (dictionary? vendored) vendor-deps-legacy vendor-deps))
  (vendor-f vendored :force-deps? force-deps?))

(defn run
  [args &opt jeep-config]
  (def info (util/load-meta "."))
  (def profile (get-in args [:sub :params :profile]))
  (def no-deps? (get-in args [:sub :opts "no-deps"]))
  (def force-deps? (get-in args [:sub :opts "force-deps"]))
  (unless no-deps?
    (case profile
      "system"
      (install-system info :force-deps? force-deps?)
      "build"
      (install-build info :force-deps? force-deps?)
      "vendor"
      (install-vendor info :force-deps? force-deps?)))
  # run hook
  (def man @{:info info})
  (util/local-hook :prep man profile)
  (print "Preparations completed."))
