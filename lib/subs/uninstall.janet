(import ../util)

(def config {:rules [:bundle {:help `A URL or path to a bundle of Janet code.
                                     If no value is provided, defaults to the
                                     current working directory. Multiple
                                     bundles can be separated by spaces.`
                              :splat? true}]
             :info {:about `Uninstalls a bundle of Janet code using Janet's
                           built-in support for uninstalling installed bundles.
                           If the bundle has been installed to a local
                           directory, use 'jeep --local uninstall <bundle>' to
                           uninstall that bundle.`}
             :help "Uninstall a bundle of Janet code."})

(defn run
  [args &opt jeep-config]
  (def repo (get-in args [:sub :params :bundle]))
  (if (nil? repo)
    (let [meta (util/load-meta ".")]
      (bundle/uninstall (get meta :name)))
    (each rep repo (bundle/uninstall rep))))
