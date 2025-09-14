(import ../lib/util)

(defn main
  [& args]
  (def parent (-> (dyn :current-file) util/abspath util/parent util/parent))
  (def man-dir (string parent "/man/man1/"))
  (each entry (os/dir man-dir)
  (when (string/has-suffix? ".predoc" entry)
    (def src (string man-dir entry))
    (def dest (string/slice src 0 -8))
    (def prefix (string (os/cwd) "/"))
    (def rel-src (string/replace prefix "" src))
    (def rel-dest (string/replace prefix "" dest))
    (print "converting " rel-src " to " rel-dest)
    (os/execute ["predoc" src "-o" dest] :px))))
