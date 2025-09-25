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
   `Prepares dependencies for a given profile for the current bundle.`})

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

(defn- vendor-deps
  [all-deps &named force-deps?]
  (each [dir deps] all-deps
    (each d deps
      (if (has-key? d :files)
        (util/fetch-dep dir d)
        (install/install-to dir d :force-update force-deps?)))))

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
      (if (string/has-prefix? (dyn :syspath) (dyn :current-file))
        (string (dyn :syspath) util/sep "jeep")
        (string/slice (dyn :current-file) 0 -15))
      util/sep "deps" util/sep "spork"))
  (os/mkdir bundle-dir)
  (os/mkdir (string bundle-dir util/sep "spork"))
  (print "vendoring essential build files into " bundle-dir)
  (each f essentials
    (def from (string spork-dir util/sep "spork" util/sep f))
    (def to (string bundle-dir util/sep "spork" util/sep f))
    (print "  copying " f " to " to)
    (util/copy from to))
  (def from-licence (string spork-dir util/sep "LICENSE"))
  (def to-licence (string bundle-dir util/sep "spork" util/sep "LICENSE"))
  (util/copy from-licence to-licence))

(defn- install-system
  [info &named force-deps?]
  (def system-deps (get info :dependencies []))
  (each d system-deps
    (install/install d :force-update force-deps?)))

(defn- install-vendor
  [info &named force-deps?]
  (def all-deps (->> (get info :vendored {}) (pairs)))
  (if (empty? all-deps)
    (error "no vendored dependencies in info.jdn"))
  (vendor-deps all-deps :force-deps? force-deps?))

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
