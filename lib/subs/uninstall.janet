(import ../util)

(def- helps
  {:bundle
   `A URL or path to a bundle of Janet code. If no value is provided, defaults
   to the current working directory. Multiple bundles can be separated by
   spaces.`
   :about
   `Uninstalls a bundle of Janet code using Janet's bundle/uninstall.`
   :help
   `Uninstalls a Janet code bundle.`})

(def config {:rules [:bundle {:help (helps :bundle)
                              :splat? true}]
             :info {:about (helps :about)}
             :help (helps :help)})

(defn run
  [args &opt jeep-config]
  (def repo (get-in args [:sub :params :bundle]))
  (def cnt (if repo (length repo) 1))
  (if (nil? repo)
    (let [meta (util/load-meta ".")]
      (bundle/uninstall (get meta :name)))
    (each rep repo (bundle/uninstall rep)))
  (print "Uninstallation completed."))
