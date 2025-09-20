(import ../util)

(def- helps
  {:args
   `Arguments to pass to the build function.`
   :about
   `Builds any native targets using the build function provided in the bundle's
   bundle script.`
   :help
   `Build native targets of the current bundle.`})

(def config {:rules [:args {:splat? true
                            :proxy  "build-args"
                            :help   (helps :args)}]
             :info {:about (helps :about)}
             :help (helps :help)})

(defn run
  [args &opt jeep-config]
  (os/mkdir "_build")
  (def man @{:info (util/load-meta ".")})
  (def bargs (get-in args [:sub :params :args] []))
  (util/local-hook :build man ;bargs)
  (print "Build completed."))
