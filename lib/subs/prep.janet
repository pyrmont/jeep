(import ../install)
(import ../util)

(def config {:rules ["--force" {:kind  :flag
                                :short "f"
                                :help  `Whether to force installation of
                                       dependencies.`}
                     "----"]
             :info {:about `Prepare the system for project development. This
                           will typically involve the installation of any
                           dependencies necessary for the project.`}
             :help "Prepare the system for development of the current project."})

(defn run
  [args &opt jeep-config]
  (def force? (get-in args [:sub :opts "force"]))
  (def info (util/load-meta "."))
  (def deps (get info :dependencies []))
  (each d deps
    (install/install d :force-update force? :auto-remove true)))
