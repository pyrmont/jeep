(use jpm/config)

(import jpm/cli :as jpm/cli)
(import jpm/commands :as jpm/commands)
(import jpm/pm :as jpm/pm)

(import ./argy-bargy :as argy)

(import ./subcommands/dev-deps :as cmd/dev-deps)
(import ./subcommands/netrepl :as cmd/netrepl)
(import ./subcommands/plonk :as cmd/plonk)
(import ./subcommands/test :as cmd/test)


# Configuration

(def subcommands
  ```
  Subcommands supported by jeep.
  ```
  {"help"     {:help "Show help for a subcommand."}

   "dev-deps" cmd/dev-deps/config
   "netrepl"  cmd/netrepl/config
   "plonk"    cmd/plonk/config
   "test"     cmd/test/config})


(def config
  ```
  Top-level information about the jeep tool.
  ```
  {:rules ["--config-file" {:kind :single
                            :name "FILE"
                            :help "Use FILE for configuration."}
           "--tree"  {:kind  :single
                      :help  "Use directory TREE for dependencies."}
           "--local" {:kind  :flag
                      :short "l"
                      :help  "Use directory 'jpm_tree' for dependencies."}]
   :info  {:about   "A tool for developing Janet projects"
           :opts    "The following options are available:\n"
           :subcmds "The following subcommands are available:\n"
           :rider   `If jeep does not recognize the subcommand, it will pass all
                    arguments through to jpm. For a full list of commands
                    supported by jpm, type 'jpm'.`}
  })


# Utility functions

(defn- add-tree
  [meta args]
  (if-let [tree (meta :jeep/tree)]
    (array/insert (array ;args) 1 (string "--tree=" tree))
    args))


(defn- configure
  [config-file]
  (read-env-variables)
  (if config-file
    (load-config-file config-file false)
    (load-config-file (string (dyn :syspath) "/jpm/default-config.janet") false)))


(defn- get-tree
  [opts]
  (or (and (opts "local") "jpm_tree")
      (opts "tree")))


(defn- load-project
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


(defn- process-with-jeep
  [meta sub]
  (when-let [args   (argy/parse-args-with-subcommands config subcommands)
             sub-fn (get-in subcommands [sub :fn])]
    (sub-fn meta (args :opts) (args :params))))


# Main

(defn main [& argv]
  (when-let [args (argy/parse-args-with-subcommands config subcommands true)
             opts (args :opts)
             sub  (args :sub)]
    (configure (opts "config-file"))
    (def meta (load-project (get-tree opts)))
    (setdyn :executable (dyn:janet))

    (cond
      (subcommands sub)
      (process-with-jeep meta sub)

      (jpm/commands/subcommands sub)
      (jpm/cli/main ;(add-tree meta argv))

      (do
        (argy/usage-error "unrecognized subcommand '" sub "'")
        (os/exit 1)))))
