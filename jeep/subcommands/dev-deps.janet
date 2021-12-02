(import jpm/commands :as jpm/commands)
(import jpm/pm :as jpm/pm)


(defn- cmd-fn [meta opts params]
  (if-let [tree (get-in meta [:project :jeep/tree])]
    (jpm/commands/set-tree tree))

  (jpm/commands/deps)

  (if-let [deps (get-in meta [:project :jeep/dev-dependencies])]
    (each dep deps
      (jpm/pm/bundle-install dep))
    (do (print "no dev dependencies found") (flush))))


(def config
  {:info {:about `Install dependencies and development dependencies for Janet projects

                 The dev-deps subcommand installs the dependencies that are
                 specified under the :dependencies and :jeep/dev-dependencies
                 keywords in the project.janet file.`}
   :help "Install dependencies and development dependencies."
   :fn   cmd-fn})
