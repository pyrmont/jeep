(import ../install)
(import ../util)

(def- helps
  {:profile
   `The profile to use. Valid choices are 'system', 'build' and 'vendor'.`
   :force-deps
   `Force installation of dependencies.`
   :no-deps
   `Skip installation of dependencies.`
   :no-hook
   `Skip running the prep hook.`
   :label
   `Only install deps carrying the label. Can be given more than once.`
   :no-label
   `Skip deps carrying the label. Can be given more than once.`
   :about
   `Prepares the bundle for a given profile by installing dependencies and
   running the optional prep hook. For more information, see jeep-prep(1).`
   :help
   `Prepare dependencies for a given profile for the current bundle.`})

(defn- to-label
  [s]
  # a label is read like any other value, so a leading colon makes a keyword
  # and a bare word makes a string
  (def v (util/to-value s))
  (if (or (keyword? v) (and (string? v) (not (empty? v)))) v))

(def config
  {:rules [:profile       {:default "system"
                           :help (helps :profile)}
           "--force-deps" {:kind  :flag
                           :short "f"
                           :help (helps :force-deps)}
           "--label"      {:kind  :multi
                           :short "l"
                           :value to-label
                           :help (helps :label)}
           "--no-label"   {:kind  :multi
                           :short "L"
                           :proxy "label"
                           :value to-label
                           :help (helps :no-label)}
           "--no-deps"    {:kind :flag
                           :short "D"
                           :help (helps :no-deps)}
           "--no-hook"    {:kind :flag
                           :short "H"
                           :help (helps :no-hook)}
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
        (install/install-to d dir :force-update force-deps?)))))

(defn- install-build
  [&]
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
  [info &named force-deps? labels no-labels]
  (def listed (get info :dependencies []))
  (def system-deps (util/filter-deps listed :labels labels :no-labels no-labels))
  (if (and (not (empty? listed)) (empty? system-deps))
    (print "no dependencies matched")
    (each d system-deps
      (install/install d :force-update force-deps?))))

(defn- install-vendor
  [info &named force-deps? labels no-labels]
  (def vendored (get info :vendored))
  (assert (and vendored (not (empty? vendored)))
          "no vendored dependencies in info.jdn")
  # the deprecated dictionary form has nowhere to hang a label
  (when (dictionary? vendored)
    (assert (and (empty? labels) (empty? no-labels))
            "--label and --no-label require :vendored to be an array/tuple"))
  (def deps (util/filter-deps vendored :labels labels :no-labels no-labels))
  (if (empty? deps)
    (print "no dependencies matched")
    (do
      (def vendor-f (if (dictionary? vendored) vendor-deps-legacy vendor-deps))
      (vendor-f deps :force-deps? force-deps?))))

(defn run
  [args &opt jeep-config]
  jeep-config # TODO: Add support for configuring via existing file
  (def info (util/load-meta "."))
  (def profile (get-in args [:sub :params :profile]))
  (def opts (get-in args [:sub :opts]))
  (def no-deps? (get opts "no-deps"))
  (def no-hook? (get opts "no-hook"))
  (def force-deps? (get opts "force-deps"))
  (def labels (get opts "label" []))
  (def no-labels (get opts "no-label" []))
  # install deps, making the local bundle's fallbacks available to every fetch
  (unless no-deps?
    (with-dyns [:jeep-fallbacks (get info :fallbacks)]
      (case profile
        "system"
        (install-system info :force-deps? force-deps?
                        :labels labels :no-labels no-labels)
        "build"
        (do
          (assert (and (empty? labels) (empty? no-labels))
                  "--label and --no-label cannot be used with the build profile")
          (install-build info :force-deps? force-deps?))
        "vendor"
        (install-vendor info :force-deps? force-deps?
                        :labels labels :no-labels no-labels))))
  # run hook
  (unless no-hook?
    (def man @{:info info})
    (try
      (util/local-hook :prep man profile)
      ([e f]
       (def rider "; use --no-hook to skip loading")
       (def msg (if (= "failed to load bundle script" e) (string e rider) e))
       (propagate msg f))))
  (print "Preparations completed."))
