(import ../util)

(def config {:rules []
             :info {:about `Downloads the dependencies specified under the
                           ':vendored' key in 'info.jdn' and save these to a
                           directory within the project root.

                           The ':vendored' key should map to a struct/table. The
                           keys in the struct/table are strings and the values
                           are tuple/arrays. Each key is a directory into which
                           to vendor the dependencies defined in the
                           tuple/array. A dependency is a struct/table which
                           must include a ':url' key and optionally ':tag',
                           ':prefix', ':include' and ':exclude' keys.

                           Vendored dependencies should be imported into the
                           user's code using relative paths rather than by
                           setting Janet's syspath to be the vendored
                           directory. If the user wants to install certain
                           dependencies locally for development purposes, this
                           should be done using 'jeep --local prep'.`}
             :help "Vendor certain dependencies for the current project."})

(defn run
  [args &opt jeep-config]
  (util/vendor-deps)
  (print "All dependencies vendored."))
