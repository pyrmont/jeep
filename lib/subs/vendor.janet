(import ../util)

(def config {:rules ["--path" {:default "vendor"
                               :kind    :single
                               :proxy   "dir"
                               :short   "p"
                               :help    `The directory where the vendored
                                        dependencies will be saved.`}
                     "----"]
             :info {:about `Download the dependencies specified under the
                           :vendored key in info.jdn and save these to a
                           directory within the project root.`}
             :help "Vendor certain dependencies for the current project."})

(defn run
  [args]
  (def path (get-in args [:sub :opts "path"]))
  (util/vendor-deps path)
  )
