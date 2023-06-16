(defn- get-tree-option
  [args]
  (def globals (args :globals))
  (cond
    (get globals "local")
    "-l "

    (get globals "tree")
    (string "--tree=" (get globals "tree") " ")))


(defn- subcommand [meta args]
  (def deps (meta :dev-dependencies))
  (def tree-option (get-tree-option args))
  (each dep deps
    (os/shell (string "jpm " tree-option "install " dep))))


(def config
  {:info {:about `Install all dependencies for Janet projects

                 The dev-deps subcommand installs the dependencies that are
                 specified under the :dependencies and :dev-dependencies
                 keywords in the project.janet file.`}
   :help "Install dependencies and development dependencies."
   :fn   subcommand})
