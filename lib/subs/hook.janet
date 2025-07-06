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
             :info {:about `Run a bundle hook in the current project.`
                    :usages ["jeep hook <hook>"]
                    :rider (print-hooks)}
             :help "Run a bundle hook in the current project."})

(defn- help []
  (def cmd "jeep hook")
  (setdyn :args [cmd "--help"])
  (def msg (-> (argy/parse-args cmd config) (get :help)))
  (prin msg))

(defn run
  [args &named]
  (def [ok module] (protect (require (string util/sep "bundle"))))
  (unless ok (error "could not read 'bundle.janet' or 'bundle/init.janet'"))
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

    (do
      (def hookf (module/value module hook))
      (def hargs (array/slice sargs 1))
      (apply hookf hargs))))
