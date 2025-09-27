(import ../../lib/util)

(def- s util/sep)

(def- paths
  ["man"])

(defn- parse-args
  [args]
  (def force? (= "-f" (get args 1)))
  (def begin (if force? 2 1))
  (def pages (array/slice args begin))
  [force? pages])

(defn- special?
  [entry]
  (or (= "." entry) (= ".." entry)))

(defn main
  [& args]
  (def [force? pages] (parse-args args))
  (def threeup (comp util/parent util/parent util/parent))
  (def bundle-root (-> (dyn :current-file) util/abspath threeup))
  (def entries (map (partial string bundle-root s) paths))
  (each entry entries
    (if (= :directory (os/stat entry :mode))
      (->> (os/dir entry)
           (filter (comp not special?))
           (map (partial string entry s))
           (array/concat entries))
      (when (and (string/has-suffix? ".predoc" entry)
                 (or (empty? pages)
                     (find (fn [p] (string/has-suffix? p entry)) pages)))
        (def src entry)
        (def dest (string/slice src 0 -8))
        (def prefix (string (os/cwd) "/"))
        (when (or force?
                  (< (os/stat dest :modified)
                     (os/stat src :modified)))
          (def rel-src (string/replace prefix "" src))
          (def rel-dest (string/replace prefix "" dest))
          (print "converting " rel-src " to " rel-dest)
          (os/execute ["predoc" src "-o" dest] :px))))))
