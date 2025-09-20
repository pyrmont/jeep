(import ../deps/argy-bargy/argy-bargy :as argy)
(import ./util)

# Global Commands
(import ./subs/install :as cmd/install)
(import ./subs/quickbin :as cmd/quickbin)
(import ./subs/uninstall :as cmd/uninstall)

# Bundle Commands
(import ./subs/api :as cmd/api)
(import ./subs/build :as cmd/build)
(import ./subs/clean :as cmd/clean)
(import ./subs/dep :as cmd/dep)
(import ./subs/prep :as cmd/prep)
(import ./subs/test :as cmd/test)

(def top-config
  ```
  Top-level information about the jeep tool.
  ```
  {:rules ["--local" {:kind  :flag
                      :short "l"
                      :help  `Use the directory ./_system for the system path.`}
           "---------------------------------"]
   :info  {:about "A tool for installing, building and managing Janet bundles"
           :opts-header "The following global options are available:"
           :subs-header "The following subcommands are available:"}})

(def top-subcommands
  ```
  Subcommands supported by jeep.
  ```
  ["install" cmd/install/config
   "quickbin" cmd/quickbin/config
   "uninstall" cmd/uninstall/config
   "---"
   "api" cmd/api/config
   "build" cmd/build/config
   "clean" cmd/clean/config
   "dep" cmd/dep/config
   "prep" cmd/prep/config
   "test" cmd/test/config])

(def- file-env (curenv))

(defn run []
  (def config (merge top-config {:subs top-subcommands}))
  (def parsed (argy/parse-args "jeep" config))
  (def err (parsed :err))
  (def help (parsed :help))
  (cond
    (not (empty? help))
    (do
      (def long? (or (get-in parsed [:opts "help"])
                     (get-in parsed [:sub :opts "help"])))
      (def short? (or (get-in parsed [:opts :h?])
                      (get-in parsed [:sub :opts :h?])))
      (if (or (nil? long?)
              short?
              (get {:windows true :mingw true :cygwin true} (os/which)))
        (prin help)
        (do
          (def name (string (parsed :cmd) (when (parsed :sub) (string "-" (get-in parsed [:sub :cmd])))))
          (def path (if (dyn :jeep-cli)
                      name
                      (string (string/slice (dyn :current-file) 0 -15) "/man/man1/" name ".1")))
          (os/execute ["man" path] :p)))
      (os/exit (if long? 0 1)))
    (not (empty? err))
    (do
      (eprin err)
      (os/exit 1))
    (do
      (when (get-in parsed [:opts "local"])
        (util/change-syspath "_system"))
      (def name (symbol "cmd/" (get-in parsed [:sub :cmd]) "/run"))
      (def sub/run (module/value file-env name true))
      (try
        (sub/run parsed)
        ([e f]
         (eprint "error: " e)
         (if (os/getenv "JEEP_DEBUG")
           (debug/stacktrace f))
         (os/exit 1))))))

(defn main [& args] (run))
