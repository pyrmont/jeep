(import ../install)

(def- helps
  {:bundle
   `A URL or path to a bundle of Janet code. If no value is provided, defaults
   to the current working directory. Multiple bundles can be separated by
   spaces.`
   :replace
   `Replace bundles with conflicting names.`
   :about
   `Installs a bundle of Janet code using Janet's bundle/install.`
   :help
   `Install a Janet code bundle.`})

(def config {:rules [:bundle {:splat? true
                              :help (helps :bundle)}
                     "--replace" {:kind  :flag
                                  :short "r"
                                  :help  (helps :replace)}
                     "---"]
             :info {:about (helps :about)}
             :help (helps :help)})

(defn run
  [args &opt jeep-config]
  (def repo (get-in args [:sub :params :bundle]))
  (def replace? (get-in args [:sub :opts "replace"]))
  (if (nil? repo)
    (install/install "file::." :replace? replace? :force-update true :no-deps true)
    (each rep repo
      (def [ok? res] (protect (parse rep)))
      (install/install (if (and ok? (dictionary? res)) res rep)
                       :replace? replace?
                       :force-update true)))
  (print "Installation completed."))
