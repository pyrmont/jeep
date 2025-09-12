(import ../util)

(def- helps
  {:build
   `Delete the ./_build directory.`
   :system
   `Delete the ./_system directory.`
   :about
   `Cleans certain directories using the clean function provided in the
   project's bundle script.`
   :help
   `Clean directories of the current project.`})

(def config {:rules ["--build" {:kind  :flag
                                :short "b"
                                :help  (helps :build)}
                     "--system" {:kind  :flag
                                 :short "s"
                                 :help  (helps :system)}
                     "----"]
             :info {:about (helps :about)}
             :help (helps :help)})

(defn run
  [args &opt jeep-config]
  (def opts (get-in args [:sub :opts]))
  (util/local-hook :clean)
  (if (get opts "build")
    (util/rmrf "_build"))
  (if (get opts "syspath")
    (util/rmrf "_system"))
  (print "Cleaning completed."))
