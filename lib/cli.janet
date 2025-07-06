(import ../deps/argy-bargy/argy-bargy :as argy)
(import ./util)

# commands
(import ./subs/hook :as cmd/hook)
(import ./subs/install :as cmd/install)
(import ./subs/prep :as cmd/prep)
(import ./subs/uninstall :as cmd/uninstall)
(import ./subs/vendor :as cmd/vendor)

(def top-config
  ```
  Top-level information about the jeep tool.
  ```
  {:rules ["--local" {:kind  :flag
                      :short "l"
                      :help  `Use a local directory for the system path. Jeep will
                             use the ':syspath' value in '.jeep/config.jdn' if
                             it exists, otherwise it uses '_modules'.`}
           "---------------------------------"]
   :info  {:about "A tool for installing, building and managing Janet projects"
           :opts-header "The following global options are available:"
           :subs-header "The following subcommands are available:"}})

(def top-subcommands
  ```
  Subcommands supported by jeep.
  ```
  ["install" cmd/install/config
   "uninstall" cmd/uninstall/config
   "---"
   "hook" cmd/hook/config
   "prep" cmd/prep/config
   "vendor" cmd/vendor/config])

(defn run []
  (def config (merge top-config {:subs top-subcommands}))
  (def parsed (argy/parse-args "jeep" config))
  (def err (parsed :err))
  (def help (parsed :help))
  (cond
    (not (empty? help))
    (do
      (prin help)
      (os/exit (if (get-in parsed [:opts "help"]) 0 1)))
    (not (empty? err))
    (do
      (eprin err)
      (os/exit 1))
    (do
      (def jeep-config-path (string/join ["." ".jeep" "config.jdn"] util/sep))
      (def jeep-config (when (util/fexists? jeep-config-path) (parse (slurp jeep-config-path))))
      (def local-dir (when (get-in parsed [:opts "local"])
                       (or (get jeep-config :syspath) "_modules")))
      (def name (symbol "cmd/" (get-in parsed [:sub :cmd]) "/run"))
      (def sub/run (module/value (curenv) name true))
      (try
        (sub/run parsed :local-dir local-dir)
        ([e _]
         (eprint e)
         (os/exit 1))))))

(defn- main [& args] (run))
