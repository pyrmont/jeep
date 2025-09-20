(import ../../lib/util)

(defn main
  [& args]
  (def pages (array/slice args 1))
  (def threeup (comp util/parent util/parent util/parent))
  (def bundle-root (-> (dyn :current-file) util/abspath threeup))
  (def man-dir (string bundle-root "/man/man1/"))
  (each entry (os/dir man-dir)
    (when (and (string/has-suffix? ".predoc" entry)
               (or (empty? pages)
                   (find (fn [p] (string/has-suffix? p entry)) pages)))
      (def src (string man-dir entry))
      (def dest (string/slice src 0 -8))
      (def prefix (string (os/cwd) "/"))
      (def rel-src (string/replace prefix "" src))
      (def rel-dest (string/replace prefix "" dest))
      (print "converting " rel-src " to " rel-dest)
      (os/execute ["predoc" src "-o" dest] :px))))
