(import ../../lib/util)

(defn main
  [& args]
  (def project-root (-> (dyn :current-file)
                        (util/abspath)
                        (util/parent 3)))
  (def info (util/load-meta project-root))
  (each dep (get info :vendored)
    (util/fetch-dep dep)))
