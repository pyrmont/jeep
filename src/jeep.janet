(import jpm/init :as jpm)
(import jpm/cli :as jpm/cli)
(import spork/netrepl)

(import ./argy-bargy :as argy)

(import ./subcommands/dev-deps :as cmd/dev-deps)
(import ./subcommands/netrepl :as cmd/netrepl)
(import ./subcommands/test :as cmd/test)


# Configuration

(def subcommands
  ```
  Subcommands supported by jeep.
  ```
  {"help"     {:help "Show help for a subcommand."}

   "dev-deps" cmd/dev-deps/config
   "netrepl"  cmd/netrepl/config
   "test"     cmd/test/config})


(def config
  ```
  Top-level information about the jeep tool.
  ```
  {:rules ["--tree"  {:kind  :single
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


# Global bindings

(def- meta @{})
(def- executable (dyn :executable))


# Utility functions

(defn- add-tree
  [args]
  (if-let [tree (meta :jeep/tree)]
    (array/insert (array ;args) 1 (string "--tree=" tree))
    args))


(defn- find-subcommand
  [args]
  (def num-args (length args))
  (var i 1)
  (while (< i num-args)
    (def arg (get args i))
    (if (string/has-prefix? "-" arg)
      (++ i)
      (break)))
  (get args i))


(defn- load-project
  []
  (def env (jpm/pm/require-jpm "./project.janet" true))
  (merge-into meta (env :project)))


(defn- process-with-jeep
  []
  (when-let [args (argy/parse-args-with-subcommands config subcommands)
             opts (args :opts)
             cmd  (-> subcommands (get (args :sub)) (get :fn))]
    (when-let [tree (or (when (opts "local") "jpm_tree")
                        (opts "tree")
                        (meta :jeep/tree))]
      (jpm/commands/set-tree tree))
    (cmd meta (args :opts) (args :params))))


(defn- setup
  []
  (setdyn :executable executable)
  (jpm/config/read-env-variables)
  (if-let [cd (dyn :jpm-config)]
    (jpm/config/load-config cd true)
    (if-let [cf (dyn :config-file (os/getenv "JANET_JPM_CONFIG"))]
      (jpm/config/load-config-file cf false)
      (jpm/config/load-config jpm/default-config/config false))))


# Main

(defn main [& argv]
  (setup)
  (load-project)

  (def subcommand (find-subcommand (dyn :args)))

  (cond
    (subcommands subcommand)
    (process-with-jeep)

    (jpm/commands/subcommands subcommand)
    (jpm/cli/main ;(add-tree argv))

    (process-with-jeep)))
