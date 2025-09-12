(import ../install)

(def- helps
  {:bundle
   `A URL or path to a bundle of Janet code. If no value is provided, defaults
   to the current working directory. Multiple bundles can be separated by
   spaces.`
   :about
   `Installs a bundle of Janet code using Janet's bundle/install.`
   :help
   `Install a Janet code bundle.`})

(def config {:rules [:bundle {:help (helps :bundle)
                              :splat? true}]
             :info {:about (helps :about)}
             :help (helps :help)})

(defn run
  [args &opt jeep-config]
  (def repo (get-in args [:sub :params :bundle]))
  (if (nil? repo)
    (install/install "file::." :force-update true :no-deps true)
    (each rep repo (install/install rep :force-update true)))
  (print "Installation completed."))
