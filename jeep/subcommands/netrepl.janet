(import spork/netrepl)


(defn- cmd-fn [meta opts params]
  (def syspath (dyn :modpath))

  (defn netrepl-env [& args]
    (def env (make-env))
    (put env :syspath syspath)
    (put env :pretty-format (opts "format")))

  (netrepl/server (opts "host") (opts "port") netrepl-env))


(def config
  {:rules ["--format" {:kind    :single
                       :help    "The format to use for output."
                       :default "%.20m"}
           "--host" {:kind    :single
                     :help    "The hostname for the netrepl server."
                     :default "127.0.0.1"}
           "--port" {:kind    :single
                     :help    "The port for the netrepl server."
                     :default 9365
                     :value   :integer}]
   :info  {:about `Start a netrepl server for Janet projects

                  The netrepl subcommand starts a netrepl server to which
                  clients can connect.`}
   :help  "Start a netrepl server."
   :fn    cmd-fn})
