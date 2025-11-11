(import ../../deps/spork/declare-cc :as dcc)

(def- helps
  {:script
   `The Janet script with a main function.`
   :exe
   `The name of the executable to create.`
   :about
   `Creates a binary executable from a Janet script. The script must have a main
   function.`
   :help
   `Create a binary executable from a Janet script.`})


(def config {:rules [:script {:help (helps :script)
                              :req? true}
                     :exe {:help (helps :exe)
                           :req? true}]
             :info {:about (helps :about)}
             :help (helps :help)})

(defn run
  [args &opt jeep-config]
  (def params (get-in args [:sub :params]))
  (dcc/quickbin (params :script) (params :exe))
  (print "Executable created."))
