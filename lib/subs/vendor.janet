(import ../util)

(def config {:rules ["--path" {:default "vendor"
                               :kind    :single
                               :proxy   "dir"
                               :short   "p"
                               :help    `The directory where the vendored
                                        dependencies will be saved.`}
                     "----"]
             :info {:about `Downloads the dependencies specified under the
                           ':vendored' key in 'info.jdn' and save these to a
                           directory within the project root.

                           Vendored dependencies should be imported into the
                           user's code using relative paths rather than by
                           setting Janet's syspath to be the vendored
                           directory. If the user wants to install certain
                           dependencies locally for development purposes, this
                           should be done using 'jeep --local prep'.`}
             :help "Vendor certain dependencies for the current project."})

(defn run
  [args &opt jeep-config]
  (def path (get-in args [:sub :opts "path"]))
  (util/vendor-deps path)
  (print "All dependencies vendored."))
