(import argy-bargy :as argy)

(import ./subcommands/dev-deps :as cmd/dev-deps)
# (import ./subcommands/netrepl :as cmd/netrepl)
# (import ./subcommands/plonk :as cmd/plonk)


# Configuration

(def subcommands
  ```
  Subcommands supported by jeep.
  ```
  {"help"     {:help "Show help for a subcommand."
               :info {:about `Yes, very funny`}}
   "dev-deps" cmd/dev-deps/config
   # "netrepl"  cmd/netrepl/config
   # "plonk"    cmd/plonk/config
   })


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


# Utilities

(defn- get-subcommand
  ```
  Find the first subcommand in an array
  ```
  [argv]
  (find (fn [x] (not (string/has-prefix? "-" x))) (array/slice argv 1)))


(defn- get-meta
  ```
  Get the metadata for the project
  ```
  []
  (def meta @{})
  (unless (nil? (get (os/stat "./project.janet") :mode))
    (def p (parser/new))
    (parser/consume p (slurp "./project.janet"))
    (parser/eof p)
    (while (parser/has-more p)
      (def form (parser/produce p))
      (when (= 'declare-project (first form))
        (merge-into meta (struct ;(tuple/slice form 1)))
        (break))))
  meta)


# Main

(defn main [& argv]
  (def out @"")
  (def err @"")
  (def args (with-dyns [:out out :err err]
              (argy/parse-args-with-subcommands config subcommands)))
  (def subcommand (args :sub))
  (def pass-thru? (not (or (nil? subcommand)
                           (= "help" subcommand)
                           (subcommands subcommand))))
  (def errored? (args :error?))
  (def helped? (args :help?))

  (cond
    pass-thru?
    (os/shell (string "jpm " (string/join (array/slice argv 1) " ")))

    errored?
    (eprin err)

    helped?
    (prin out)

    (((subcommands subcommand) :fn) (get-meta) args)))
