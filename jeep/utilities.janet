(import jpm/pm :as jpm/pm)


(defn add-tree
  [meta args]
  (if-let [tree (meta :jeep/tree)]
    (array/insert (array ;args) 1 (string "--tree=" tree))
    args))


(defn get-tree
  [opts]
  (or (and (opts "local") "jpm_tree")
      (opts "tree")))


(defn load-project
  [tree]
  (case (get (os/stat "./project.janet") :mode)
    nil
    {}

    :file
    (do
      (def env (jpm/pm/require-jpm "./project.janet" true))
      (def meta (merge (env :project) {:jeep/tree tree} {:jeep/exes @[]}))
      (def src (slurp "./project.janet"))
      (def p (parser/new))
      (parser/consume p src)
      (parser/eof p)
      (while (parser/has-more p)
        (def form (parser/produce p))
        (when (= 'declare-executable (first form))
          (def exe (struct ;(tuple/slice form 1)))
          (array/push (meta :jeep/exes) exe)))
      meta)))
