(import argy-bargy :as argy)

(import ./subcommands/dev-deps :as cmd/dev-deps)
(import ./subcommands/doc :as cmd/doc)
(import ./subcommands/netrepl :as cmd/netrepl)
# (import ./subcommands/plonk :as cmd/plonk)


# Configuration

(def builtin-subcommands
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
           :opts    "The following global options are available:\n"
           :subcmds "The following subcommands are available:\n"
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


(defn- get-subconfig
  ```
  Gets the subconfig
  ```
  [subcommand subcommands]
  (def i (find-index (fn [x] (= subcommand x)) subcommands))
  (unless (nil? i)
    (get subcommands (inc i))))


(defn load-subcommands
  ```
  Loads the subcommands
  ```
  [builtins]
  (def subconfigs (table ;builtins))
  (def user-dir (string (os/getenv "HOME" "~") "/.jeep/subcommands"))
  (def dir-exists? (= :directory (os/stat user-dir :mode)))
  (when dir-exists?
    (each filename (os/dir user-dir)
      (when (string/has-suffix? ".janet" filename)
        (def path (string user-dir "/" filename))
        (def basename (string/slice filename 0 -7))
        (def env (dofile path))
        (unless (env 'config)
          (error (string path ": missing `config` binding")))
        (put subconfigs basename (get-in env ['config :value])))))
  (reduce (fn [result name] (array/push result name (subconfigs name)))
          @[]
          (sort (keys subconfigs))))


# Main

(defn main [& argv]
  (def subcommands (load-subcommands builtin-subcommands))
  (def out @"")
  (def err @"")
  (def args (with-dyns [:out out :err err]
              (argy/parse-args-with-subcommands config subcommands)))
  (def subcommand (args :sub))
  (def subconfig (get-subconfig subcommand subcommands))
  (def pass-thru? (not (or (nil? subcommand)
                           (= "help" subcommand)
                           subconfig)))
  (def errored? (args :error?))
  (def helped? (args :help?))

  (cond
    pass-thru?
    (os/shell (string "jpm " (string/join (array/slice argv 1) " ")))

    errored?
    (eprin err)

    helped?
    (prin out)

    ((subconfig :fn) (get-meta) args)))
