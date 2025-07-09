(import ../util)

(def config {:rules ["--build" {:kind    :flag
                                :short   "b"
                                :help    "Delete the build directory."}
                     "--syspath" {:kind  :flag
                                  :short "s"
                                  :help  "Delete the local syspath directory."}
                     "----"]
             :info {:about `Cleans the contents of certain directories using
                           the clean hook defined in the project's
                           'bundle.janet' or 'bundle/init.janet' file. The user
                           can also delete the build and syspath directories
                           using command line options.`}
             :help "Clean directories of the current project."})

(defn run
  [args &opt jeep-config]
  (def opts (get-in args [:sub :opts]))
  (util/local-hook :clean)
  (if (get opts "build")
    (util/rmrf "_build"))
  (if (get opts "syspath")
    (util/rmrf "_modules"))
  (print "Cleaning completed."))
