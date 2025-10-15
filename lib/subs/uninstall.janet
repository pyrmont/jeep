(import ../util)

(def- helps
  {:name
   `A name of an installed bundle. Multiple bundles can be separated by spaces.`
   :about
   `Uninstalls a bundle of Janet code. Uses Janet's bundle/uninstall for modern
   bundles and otherwise removes files at the paths specified in the legacy
   bundle manifest.`
   :help
   `Uninstall a Janet code bundle.`})

(def config {:rules [:name {:help (helps :name)
                            :splat? true}]
             :info {:about (helps :about)}
             :help (helps :help)})

(defn- legacy-mpath
  [name]
  (def s util/sep)
  (string (dyn :syspath) s ".manifests" s name ".jdn"))

(defn- legacy-manifest
  [name]
  (-?> (legacy-mpath name) util/slurp-maybe parse))

(defn- uninstall
  [name &opt legacy?]
  (when (= "jeep" name)
    (eprint "cannot remove jeep with jeep, instead run 'janet -u jeep'")
    (break))
  # so easy if a modern bundle
  (unless legacy?
    (bundle/uninstall name)
    (break))
  # check no breakage
  (def breakage @{})
  (each b (util/legacy-bundles)
    (unless (= b name)
      (def m (legacy-manifest b))
      (def deps (get m :dependencies []))
      (each d deps
        (if (= d name) (put breakage b true)))))
  (when (next breakage)
    (def breaks (sorted (keys breakage)))
    (errorf "cannot uninstall %s, breaks dependent bundles %n" name breaks))
  # remove all paths created during installation
  (when (def man (legacy-manifest name))
    (each p (get man :paths)
      (print "remove " p)
      (def [ok? res] (protect (util/rmrf p)))
      (unless ok?
        (eprint "cannot remove " p " (" res ")"))
      # hack to remove prefix directory
      (when (string/has-prefix? (dyn :syspath) p)
        (def parent (util/parent p))
        (def [ok? _] (protect (os/rmdir parent)))
        (if ok? (print "remove " parent))))
    # remove manifest file
    (def mpath (legacy-mpath name))
    (def [ok? res] (protect (util/rmrf mpath)))
    (unless ok?
      (eprint "cannot remove " mpath " (" res ")"))))

(defn run
  [args &opt jeep-config]
  (def repo (get-in args [:sub :params :name]))
  (if (nil? repo)
    (let [meta (util/load-meta ".")]
      (uninstall (get meta :name)))
    (do
      (def lbundles (util/legacy-bundles))
      (def mbundles (bundle/list))
      (each rep repo
        (def legacy? (index-of rep lbundles))
        (def modern? (index-of rep mbundles))
        (unless (or legacy? modern?)
          (errorf "no bundle %s installed" rep))
        (if (and legacy? modern?)
          (do
            (uninstall rep)
            (uninstall rep true))
          (uninstall rep legacy?)))))
  (print "Uninstallation completed."))
