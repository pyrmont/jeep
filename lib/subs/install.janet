(import ../install)

(def config {:rules [:bundle {:help `A URL or path to a bundle of Janet code.
                                     If no value is provided, defaults to the
                                     current working directory.`
                              :splat? true}]
             :info {:about `Install a bundle of Janet code.`}
             :help "Install a bundle of Janet code."})

(defn run
  [args &opt jeep-config]
  (def repo (get-in args [:sub :params :bundle]))
  (if (nil? repo)
    (install/install "file::." :force-update true :no-deps true)
    (each rep repo (install/install rep :force-update true))))
