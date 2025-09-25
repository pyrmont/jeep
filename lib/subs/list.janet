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
  (def pad (if no-legacy? "" " "))
  (def mbundles (bundle/list))
  (def lbundles (if no-legacy? [] (util/legacy-bundles)))
  (def bundles (array/concat @[] mbundles lbundles))
  (print "Installed bundles"
         (if (or no-legacy? (empty? lbundles)) "" " (legacy bundles marked with *)")
         ":")
  (each b (sort bundles)
    (if (index-of b lbundles)
      (print pad "* " b)
      (print pad "  " b)))
  (print "Listing completed."))
