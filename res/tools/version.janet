(import ../../lib/util)
(import ./man)

(def- paths
  ["info.jdn"
   "man/man1"])

(defn- update-jdn
  [path new-ver]
  (def contents (slurp path))
  (def curr-ver (first (peg/match '(* (thru `:version "`) '(to `"`)) contents)))
  (if (nil? curr-ver)
    (error (string path " missing version line")))
  (def curr-line (string `:version "` curr-ver `"`))
  (def new-line (string `:version "` new-ver `"`))
  (def updated (string/replace curr-line new-line contents))
  (spit path updated)
  (print "updated " path " to version " new-ver))

(defn- update-predoc
  [path new-ver]
  (def contents (slurp path))
  (def curr-ver (first (peg/match '(* (thru "Version: ") '(to "\n")) contents)))
  (if (nil? curr-ver)
    (error (string path " missing version line")))
  (def curr-line (string `Version: ` curr-ver))
  (def new-line (string `Version: ` new-ver))
  (def updated (string/replace curr-line new-line contents))
  (spit path updated)
  (print "updated " path " to version " new-ver))

(defn main
  [command version & args]
  (def parent (-> (dyn :current-file) util/abspath util/parent util/parent))
  (def to-update (array/concat @[] paths))
  (each path to-update
    (unless (or (= "." path) (= ".." path))
      (def dir? (= :directory (os/stat path :mode)))
      (if dir?
        (array/concat to-update (map (fn [x] (string path "/" x)) (os/dir path)))
        (cond
          (string/has-suffix? ".jdn" path)
          (update-jdn path version)
          (string/has-suffix? ".predoc" path)
          (update-predoc path version)))))
  (man/main))
