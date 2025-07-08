(import ../util)

(def config {:rules [:args {:splat? true
                            :help   "Arguments to pass to the build hook."}]
             :info {:about `Builds any native targets using the build hook
                           defined in the project's 'bundle.janet' or
                           'bundle/init.janet' file. By default, creates a
                           '_build' directory in the project root.`}
             :help "Build native targets of the current project."})

(defn run
  [args &opt jeep-config]
  (os/mkdir "_build")
  (def bargs (get-in args [:sub :params :args] []))
  (util/local-hook :build ;bargs))
