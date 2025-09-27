(import ../util)

(def- helps
  {:build
   `Delete the ./_build directory.`
   :system
   `Delete the ./_system directory.`
   :about
   `Cleans certain directories using the clean function provided in the
   bundle's bundle script. Deletes all files in the _build directory.`
   :help
   `Clean directories of the current bundle.`})

(def config {:rules ["--build" {:kind  :flag
                                :short "b"
                                :help  (helps :build)}
                     "--system" {:kind  :flag
                                 :short "s"
                                 :help  (helps :system)}
                     "----"]
             :info {:about (helps :about)}
             :help (helps :help)})

(def- bdir "_build")
(def- sdir "_system")

(defn run
  [args &opt jeep-config]
  (def opts (get-in args [:sub :opts]))
  (var cleaned? false)
  (set cleaned? (util/local-hook :clean))
  (when (= :directory (os/stat bdir :mode))
    (set cleaned? true)
    (each entry (os/dir bdir)
      (unless (= "." entry) (= ".." entry))
      (util/rmrf (string bdir util/sep entry))))
  (when (get opts "build")
    (set cleaned? true)
    (util/rmrf bdir))
  (when (get opts "system")
    (set cleaned? true)
    (util/rmrf sdir))
  (if cleaned?
    (print "Cleaning completed.")
    (print "No files to clean.")))
