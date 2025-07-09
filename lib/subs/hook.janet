(import ../../deps/argy-bargy/argy-bargy :as argy)
(import ../util)

(def [module-loaded? module] (protect (require "/bundle")))

(defn- print-hooks []
  (when module-loaded?
    (def hooks (sort (reduce (fn [res [k v]]
                  (if (and (symbol? k)
                           (nil? (get v :private)))
                    (array/push res k))
                  res)
                @[]
                (pairs module))))
    (string/join ["Hooks:\n" ;hooks] "\n")))

(def config {:rules nil
             :info {:about `Runs the bundle hook defined in the 'bundle.janet'
                           or 'bundle/init.janet' file.

                           Bundle hooks typically expect a struct/table containing the
                           values in the bundle manifest as the first argument.
                           However, since the hook command is used during
                           development when the bundle has not been installed,
                           hooks called with 'jeep hook' are given an empty
                           table as the first argument.

                           All arguments given after the name of the hook,
                           including both parameters and options are passed
                           through as arguments to the hook.`
                    :usages ["Usage: jeep hook <hook>"]
                    :rider (print-hooks)}
             :help "Run a bundle hook in the current project."})

(defn- help []
  (def cmd "jeep hook")
  (setdyn :args [cmd "--help"])
  (def msg (-> (argy/parse-args cmd config) (get :help)))
  (prin msg))

(defn run
  [args &opt jeep-config]
  (unless module-loaded? (error "could not read 'bundle.janet' or 'bundle/init.janet'"))
  (def sargs (get-in args [:sub :args]))
  (def arg1 (first sargs))
  (def hook (-?> (first sargs) symbol))
  (cond
    (or (nil? arg1)
        (= "--help" arg1)
        (= "-h" arg1))
    (help)

    (nil? (get module hook))
    (errorf "no hook '%s', type 'jeep hook' for a list of valid hooks" hook)

    (util/local-hook hook ;(array/slice sargs 1))))
