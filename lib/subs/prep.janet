(import ../install)
(import ../util)

(def config {:rules ["--force-deps" {:kind  :flag
                                :short "f"
                                :help  `Force installation of
                                       dependencies.`}
                     "--no-deps" {:kind :flag
                                  :help "Skip installation of dependencies."}
                     "----"]
             :info {:about `Prepares the system for project development. If the
                           user has a 'prep' hook in the project's
                           'bundle.janet' or 'bundle/init.janet' file, this will
                           be run first. After this, any dependencies specified
                           under the ':dependencies' key in the 'info.jdn' file
                           will be installed.`}
             :help "Prepare the system for development of the current project."})

(defn run
  [args &opt jeep-config]
  (util/local-hook :prep)
  (def info (util/load-meta "."))
  (def no-deps? (get-in args [:sub :opts "skip"]))
  (def deps (unless no-deps? (get info :dependencies)))
  (def force? (get-in args [:sub :opts "force"]))
  (if deps
    (each d deps
      (install/install d :force-update force? :auto-remove true)))
  (print "Ready for development."))
