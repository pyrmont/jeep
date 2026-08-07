(import ../util)

(def- helps
  {:name
   `A name of an installed bundle. Multiple bundles can be separated by spaces.`
   :about
   `Uninstalls a bundle of Janet code. Uses Janet's bundle/uninstall for Janet
   bundles and otherwise removes files at the paths specified in the JPM bundle
   manifest.`
   :help
   `Uninstall a Janet code bundle.`})

(def config {:rules [:name {:help (helps :name)
                            :splat? true}]
             :info {:about (helps :about)}
             :help (helps :help)})

(defn- jpm-mpath
  [name]
  (def s util/sep)
  (string (dyn :syspath) s ".manifests" s name ".jdn"))

(defn- jpm-manifest
  [name]
  (-?> (jpm-mpath name) util/slurp-maybe parse))

(defn- uninstall
  [name &opt jpm?]
  (when (= "jeep" name)
    (eprint "cannot remove jeep with jeep, instead run 'janet -u jeep'")
    (break))
  # so easy if a Janet bundle
  (unless jpm?
    (bundle/uninstall name)
    (break))
  # check no breakage
  (def breakage @{})
  (each b (util/jpm-bundles)
    (unless (= b name)
      (def m (jpm-manifest b))
      (def deps (get m :dependencies []))
      (each d deps
        (if (= d name) (put breakage b true)))))
  (when (next breakage)
    (def breaks (sorted (keys breakage)))
    (errorf "cannot uninstall %s, breaks dependent bundles %n" name breaks))
  # remove all paths created during installation
  (when (def man (jpm-manifest name))
    (each p (get man :paths)
      (print "remove " p)
      (def [p-ok? p-res] (protect (util/rmrf p)))
      (unless p-ok?
        (eprint "cannot remove " p " (" p-res ")"))
      # hack to remove prefix directory
      (when (string/has-prefix? (dyn :syspath) p)
        (def parent (util/parent p))
        (def [parent-ok? _] (protect (os/rmdir parent)))
        (if parent-ok? (print "remove " parent))))
    # remove manifest file
    (def mpath (jpm-mpath name))
    (def [mpath-ok? mpath-res] (protect (util/rmrf mpath)))
    (unless mpath-ok?
      (eprint "cannot remove " mpath " (" mpath-res ")"))))

(defn run
  [args &opt jeep-config]
  jeep-config # TODO: Add support for configuring via existing file
  (def repo (get-in args [:sub :params :name]))
  (if (nil? repo)
    (let [meta (util/load-meta ".")]
      (uninstall (get meta :name)))
    (do
      (def jpm-bundles (util/jpm-bundles))
      (def janet-bundles (bundle/list))
      (each rep repo
        (def jpm? (index-of rep jpm-bundles))
        (def janet? (index-of rep janet-bundles))
        (unless (or jpm? janet?)
          (errorf "no bundle %s installed" rep))
        (if (and jpm? janet?)
          (do
            (uninstall rep)
            (uninstall rep true))
          (uninstall rep jpm?)))))
  (print "Uninstallation completed."))
