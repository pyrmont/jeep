(import ../lib/util)

(defn main
  [& args]
  (def project-root (-> (dyn :current-file)
                        util/abspath
                        util/parent
                        util/parent))
  (def info (util/load-meta project-root))
  (each [dir deps] (pairs (get info :vendored))
    (each d deps
      (util/fetch-dep dir d))))
