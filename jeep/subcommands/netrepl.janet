(import jpm/commands :as jpm/commands)

(import ../netrepl)


(defn- cmd-fn [meta opts params]
  (if-let [tree (meta :jeep/tree)]
    (jpm/commands/set-tree tree))

  (def syspath (dyn :modpath (dyn :syspath)))

  (def user-env (eval-string (or (opts "env") "{}")))

  (defn netrepl-env [& args]
    (def env (make-env))
    (put env :syspath syspath)
    (put env :pretty-format (opts "format"))
    (put env :redef (opts "redef"))
    (merge-into env user-env))

  (netrepl/server (opts "host") (opts "port") netrepl-env))


(def config
  {:rules ["--env" {:kind    :single
                    :help    "A struct to use to create the netrepl environment."
                    :default "{}"}
           "--format" {:kind    :single
                       :help    "The format to use for output."
                       :default "%.20m"}
           "--host" {:kind    :single
                     :help    "The hostname for the netrepl server."
                     :default "127.0.0.1"}
           "--port" {:kind    :single
                     :help    "The port for the netrepl server."
                     :default 9365
                     :value   :integer}
           "--redef" {:kind  :flag
                      :help  "Enable redefinable bindings in the netrepl environment."
                      :short "r"}]
   :info  {:about `Start a netrepl server for Janet projects

                  The netrepl subcommand starts a netrepl server to which
                  clients can connect.`}
   :help  "Start a netrepl server."
   :fn    cmd-fn})
