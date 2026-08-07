(import ../util)

(def- helps
  {:no-jpm
   `Exclude JPM bundles from the list.`
   :about
   `Lists system information, including installed bundles.`
   :help
   `List system information, including installed bundles.`})

(def config {:rules ["--no-jpm" {:help  (helps :no-jpm)
                                 :kind  :flag
                                 :short "J"}
                     "---"]
             :info {:about (helps :about)}
             :help (helps :help)})

(defn run
  [args &opt jeep-config]
  jeep-config # TODO: Add support for configuring via existing file
  (def no-jpm? (get-in args [:sub :opts "no-jpm"]))
  (def janet-bundles (bundle/list))
  (def jpm-bundles (if no-jpm? [] (util/jpm-bundles)))
  (def bundles (array/concat @[] janet-bundles jpm-bundles))
  (def pad (if no-jpm? "" " "))
  (print "Installed bundles"
         (if (or no-jpm? (empty? jpm-bundles)) "" " (JPM bundles marked with *)")
         ":")
  (if (empty? bundles)
    (print pad "  No bundles installed")
    (do
      (each b (sort (distinct bundles))
        (if (index-of b janet-bundles)
          (do
            (def man (bundle/manifest b))
            (def ver (or (get man :version)
                         (get-in man [:info :version])))
            (print pad "  " b (when ver (string " (" ver ")"))))
          (do
            (def man (-> (string (dyn :syspath) util/sep ".manifests" util/sep b ".jdn")
                         slurp
                         parse))
            (def ver (get man :version))
            (print pad "* " b (when ver (string " (" ver ")"))))))))
  (print "\nSystem:")
  (print pad "  version: " janet/version "-" janet/build)
  (print pad "  platform: " (os/which) "/" (os/arch) "/" (os/compiler))
  (print pad "  syspath: " (dyn :syspath))
  (def environ (os/environ))
  (print "\nEnvironment:")
  (print pad "  JANET_PATH: " (get environ "JANET_PATH" "<undefined>"))
  (print pad "  jeep: " (util/version))
  (print "\nListing completed."))
