(import ../../deps/spork/spork/pm)

(def config {:rules [:bundle {:help `A URL or path to a bundle of Janet code.
                                     If no value is provided, defaults to the
                                     current working directory.`
                              :splat? true}]
             :info {:about `Install a bundle of Janet code.`}
             :help "Install a bundle of Janet code."})

(defn run [args]
  (def repo (get-in args [:sub :params :bundle]))
  (if (nil? repo)
    (pm/pm-install "file::." :force-update true :no-deps true)
    (each rep repo (pm/pm-install rep :force-update true))))
