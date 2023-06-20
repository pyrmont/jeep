(import ./netrepl :as netrepl)


(defn- netrepl-env [name stream]
  (def e (make-env))
  (put e :pretty-format "%.20Q")
  (put e *redef* true))


(defn- subcommand [meta args]
  (def params (args :params))
  (netrepl/server (params :host) (params :port) netrepl-env))


(def config
  {:info {:about `Start a netrepl server

                 The netrepl subcommand starts a netrepl server.`}
   :rules [:port {:help    "The netrepl server port."
                  :default netrepl/default-port
                  :value   :integer}
           :host {:help    "The netrepl server host."
                  :default netrepl/default-host}]
   :help "Start a netrepl server."
   :fn   subcommand})
