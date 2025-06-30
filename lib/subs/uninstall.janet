(import ../../deps/spork/spork/pm)

(def config {:rules [:bundle {:help `A URL or path to a bundle of Janet code.
                                     If no value is provided, defaults to the
                                     current working directory.`
                              :splat? true}]
             :info {:about `Uninstall a bundle of Janet code.`}
             :help "Uninstall a bundle of Janet code."})

(defn run [args]
  (def repo (get-in args [:sub :params :bundle]))
  (if (nil? repo)
    (let [meta (pm/load-project-meta ".")]
      (bundle/uninstall (get meta :name)))
    (each rep repo (bundle/uninstall rep))))
