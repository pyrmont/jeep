(import jpm/init :as jpm)
(import jpm/cli :as jpm/cli)
(import spork/netrepl)

(import ./argy-bargy :as argy)


# Global bindings

(def- meta @{})
(def- executable (dyn :executable))


# Subcommand functions

(defn dev-deps [opts params]
  (jpm/commands/deps)
  (if-let [deps (meta :jeep/dev-dependencies)]
    (each dep deps
      (jpm/pm/bundle-install dep))
    (do (print "no dev dependencies found") (flush))))


(defn netrepl [opts params]
  (def syspath (dyn :modpath))

  (defn netrepl-env [& args]
    (def env (make-env))
    (put env :syspath syspath)
    (put env :pretty-format "%.20M"))

  (netrepl/server (opts "host") (opts "port") netrepl-env))


(defn test [opts params]
  (defn run-tests [&opt root-directory build-directory]
    (def monkey-patch
      (string
        `(setdyn :jeep/tests `
        (string/format "%j" (params :tests))
        `)
        (defn- check-is-dep [x] (unless (or (string/has-prefix? "/" x) (string/has-prefix? "." x)) x))
        (array/push module/paths  ["./build/:all:`
        (jpm/config/dyn:modext)
        `" :native check-is-dep])`))
    (def environ (merge-into (os/environ) {"JANET_PATH" (jpm/config/dyn:modpath)}))
    (var errors-found 0)
    (defn dodir
      [dir bdir]
      (each sub (sort (os/dir dir))
        (def ndir (string dir "/" sub))
        (case (os/stat ndir :mode)
          :directory
          (dodir ndir bdir)

          :file
          (when (string/has-suffix? ".janet" ndir)
            (print "running " ndir "...")
            (flush)
            (def result
              (os/execute
                [(jpm/config/dyn:janet) "-e" monkey-patch ndir]
                :ep
                environ))
            (when (not= 0 result)
              (++ errors-found)
              (eprintf "non-zero exit code in %s: %d" ndir result))))))
    (dodir "test" "build")
    (if (zero? errors-found)
      (print "All tests passed.")
      (do
        (printf "Failing test scripts: %d" errors-found)
        (os/exit 1)))
    (flush))

  (jpm/pm/import-rules "./project.janet" false)
  (def rules (jpm/rules/getrules))
  (def task (rules "test"))
  (put (task :recipe) 0 run-tests)

  (jpm/pm/do-rule "test"))


# Configuration

(def subcommands
  ```
  Subcommands supported by jeep.
  ```
  {"dev-deps" {:help  "Install dependencies and development dependencies."
               :fn    dev-deps}
   "help"     {:help  "Show help for a subcommand."}
   "netrepl"  {:rules ["--host" {:kind    :single
                                 :help    "The hostname for the netrepl server."
                                 :default "127.0.0.1"}
                       "--port" {:kind    :single
                                 :help    "The port for the netrepl server."
                                 :default 9365
                                 :value   :integer}]
               :help  "Start a netrepl server."
               :fn    netrepl}
   "test"     {:rules [:tests   {:rest true
                                 :help `One or more tests to run.`}]
               :info  {:about  `A test runner for Janet projects

                               The jeep test runner jpm's 'test' task.
                               It allows a user to provide one or more TESTS.
                               Each test file is run with the dynamic binding
                               :jpm/tests set to the value of TESTS.`}
               :help  "Run tests."
               :fn    test}})


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
             com  (-> subcommands (get (args :sub)) (get :fn))]
    (when-let [tree (or (when (opts "local") "jpm_tree")
                        (opts "tree")
                        (meta :jeep/tree))]
      (jpm/commands/set-tree tree))
    (com (args :opts) (args :params))))


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
