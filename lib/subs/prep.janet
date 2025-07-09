(import ../install)
(import ../util)

(def config {:rules ["--force-deps" {:kind  :flag
                                :short "f"
                                :help  `Force installation of
                                       dependencies.`}
                     "--no-deps" {:kind :flag
                                  :help "Skip installation of dependencies."}
                     "----"]
             :info {:about `Prepares the user's system for project development.
                           This first involves the installation of any
                           dependencies listed under the ':dependencies' key in
                           the info.jdn' file. After this, the prep hook in the
                           project's 'bundle.janet' or 'bundle/init.janet' file
                           is run.

                           The prep hook is the location that a user can define
                           additional tasks to be performed prior to development
                           (e.g. in some project's it may make sense to start a
                           server).`}
             :help "Prepare the system for development of the current project."})

(defn run
  [args &opt jeep-config]
  (def info (util/load-meta "."))
  (def no-deps? (get-in args [:sub :opts "skip"]))
  (def deps (unless no-deps? (get info :dependencies)))
  (def force? (get-in args [:sub :opts "force"]))
  (if deps
    (each d deps
      (install/install d :force-update force? :auto-remove true)))
  (print "Ready for development."))
