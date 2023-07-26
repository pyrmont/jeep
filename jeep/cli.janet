(import argy-bargy :as argy)

(import ./subcommands/dev-deps :as cmd/dev-deps)
(import ./subcommands/doc :as cmd/doc)
(import ./subcommands/netrepl :as cmd/netrepl)
# (import ./subcommands/plonk :as cmd/plonk)


# Configuration

(def default-subcommands
  ```
  Subcommands supported by jeep.
  ```
  ["dev-deps" cmd/dev-deps/config
   "doc"      cmd/doc/config
   "netrepl"  cmd/netrepl/config])


(def config
  ```
  Top-level information about the jeep tool.
  ```
  {:rules ["--tree"  {:kind  :single
                      :help  "Use directory <path> for dependencies."
                      :proxy "path"}
           "--local" {:kind  :flag
                      :short "l"
                      :help  "Use directory 'jpm_tree' for dependencies."}]
   :info  {:about   "A tool for developing Janet projects"
           :opts-header "The following global options are available:\n"
           :subs-header "The following subcommands are available:\n"
           :rider   `If jeep does not recognize the subcommand, it will pass all
                    arguments through to jpm. For a full list of commands
                    supported by jpm, type 'jpm'.`}
  })


# Utilities

(defn- get-meta
  ```
  Get the metadata for the project
  ```
  []
  (def meta @{})
  (unless (= :file (os/stat "./project.janet" :mode))
    (def p (parser/new))
    (parser/consume p (slurp "./project.janet"))
    (parser/eof p)
    (while (parser/has-more p)
      (def form (parser/produce p))
      (when (= 'declare-project (first form))
        (merge-into meta (struct ;(tuple/slice form 1)))
        (break))))
  meta)


(defn- get-subconfig
  ```
  Gets the subconfig
  ```
  [subcommands args]
  (var res nil)
  (var sub args)
  (while (set sub (get sub :sub))
    (set res (get sub :cmd)))
  res)


(defn- load-subcommands
  ```
  Loads the subcommands
  ```
  [defaults]
  (def subcommands (array ;defaults))
  (def user-file (or (os/getenv "JEEP_SUBCMDS")
                     (string (os/getenv "HOME") "/.jeep/subcommands.janet")))
  (when user-file
    (when (= :file (os/stat user-file :mode))
      (def env (dofile user-file))
      (unless (env 'subcommands)
        (error (string user-file ": missing `subcommands` binding")))
      (def users (get-in env ['subcommands :value]))
      (array/push subcommands "---")
      (array/concat subcommands users)))
  subcommands)


# Main

(defn main [& argv]
  (def subcommands (load-subcommands default-subcommands))
  (def out @"")
  (def err @"")
  (def args (with-dyns [:out out :err err]
              (argy/parse-args "jeep" (merge config {:subs subcommands}))))

  (when (string/has-prefix? "jeep: unrecognized subcommand" err)
    (os/exit (os/shell (string "jpm " (string/join (array/slice argv 1) " ")))))

  (cond
      (args :help?)
      (prin out)

      (args :error?)
      (eprin err)

      (do
        (def subconfig (get-subconfig subcommands args))
        (if subconfig
          ((subconfig :fn) (get-meta) args)
          (eprint "jeep: missing subcommand\nTry 'jeep --help' for more information.")))))
