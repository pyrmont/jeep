(import ../util)

(def- helps
  {:no-legacy
   `Exclude legacy bundles from the list.`
   :about
   `Lists the installed Janet bundles.`
   :help
   `List the installed Janet bundles.`})

(def config {:rules ["--no-legacy" {:help  (helps :no-legacy)
                                    :kind  :flag
                                    :short "L"}
                     "---"]
             :info {:about (helps :about)}
             :help (helps :help)})

(defn run
  [args &opt jeep-config]
  (def no-legacy? (get-in args [:sub :opts "no-legacy"]))
  (def mbundles (bundle/list))
  (def lbundles (if no-legacy? [] (util/legacy-bundles)))
  (def bundles (array/concat @[] mbundles lbundles))
  (if (empty? bundles)
    (print "No bundles installed.")
    (do
      (def pad (if no-legacy? "" " "))
      (print "Installed bundles"
             (if (or no-legacy? (empty? lbundles)) "" " (legacy bundles marked with *)")
             ":")
      (each b (sort (distinct bundles))
        (if (index-of b mbundles)
          (do
            (def man (bundle/manifest b))
            (def ver (get-in man [:info :version]))
            (print pad "  " b (when ver (string " (" ver ")"))))
          (do
            (def man (-> (string (dyn :syspath) util/sep ".manifests" util/sep b ".jdn")
                         slurp
                         parse))
            (def ver (get man :version))
            (print pad "* " b (when ver (string " (" ver ")"))))))
      (print "Listing completed."))))
