(import ../../deps/argy-bargy/argy-bargy :as argy)
(import ../../deps/spork/spork/declare-cc :as dcc)


(def config {:rules [:script {:help "The Janet script with a main function."
                              :req? true}
                     :exe {:help "The name of the executable to create."
                           :req? true}]
             :info {:about `Creates a binary executable from a Janet script
                           that runs without requiring Janet to be installed.
                           The script must have a main function.`}
             :help "Create an executable out of a Janet script."})

(defn run
  [args &opt jeep-config]
  (def params (get-in args [:sub :params]))
  (dcc/quickbin (params :script) (params :exe))
  (print "Executable created."))
