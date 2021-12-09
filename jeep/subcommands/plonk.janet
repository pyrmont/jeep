(import jpm/commands :as jpm/commands)
(import jpm/pm :as jpm/pm)
(import jpm/shutil :as jpm/shutil)

(import ../utilities :as util)


(defn- sudo-copy [src dest]
  (jpm/shutil/shell "sudo" "cp" "-rf" src dest)
  (print  "copying file " src " to " dest "..."))

(defn- is-win? []
  (= :windows (os/which)))


(defn- plonk-install [exes &opt binpath sudo-copy?]
  (default binpath (dyn :binpath))
  (default sudo-copy? false)
  (if (nil? exes)
    (print "No executables to plonk")
    (each exe exes
      (def exe-name (string (exe :name) (when (is-win?) ".exe")))
      (def src (string "./build/" exe-name))
      (def dest (string binpath "/" exe-name))
      (when (= :file (get (os/stat src) :mode))
        (if sudo-copy?
          (sudo-copy src dest)
          (jpm/shutil/copy src dest))))))


(defn- plonk-local [meta &opt binpath sudo-copy?]
  (default binpath (dyn :binpath))
  (if-let [tree (meta :jeep/tree)]
    (jpm/commands/set-tree tree))
  (setdyn :syspath (dyn :modpath))
  (jpm/commands/build)
  (plonk-install (meta :jeep/exes) binpath sudo-copy?))


(defn- plonk-remote [repo &opt temp-root binpath sudo-copy?]
  (def install-root
    (string (or temp-root
                (string ((os/environ) "HOME") "/.jeep"))
            "/plonk"))
  (def remove-root? (not (nil? temp-root)))
  (defer (if remove-root? (jpm/shutil/rimraf install-root))
    (jpm/shutil/create-dirs (string install-root "/.cache"))
    (setdyn :modpath install-root)
    (def repo-dir (jpm/pm/download-bundle repo :git))
    (def old-dir (os/cwd))
    (defer (os/cd old-dir)
      (os/cd repo-dir)
      (def tree "jpm_tree")
      (jpm/commands/set-tree tree)
      (setdyn :syspath (dyn :modpath))
      (def meta (util/load-project tree))
      (jpm/commands/deps)
      (jpm/commands/build)
      (plonk-install (meta :jeep/exes) binpath sudo-copy?))))


(defn- cmd-fn [meta opts params]
  (if (params :repo)
    (plonk-remote (params :repo) (opts "temp-dir") (opts "binpath") (opts "sudo-copy"))
    (plonk-local meta (opts "binpath") (opts "sudo-copy"))))


(def config
  {:rules ["--binpath"   {:kind :single
                          :help "The binpath to use during installation (Default: system :binpath)"
                          :name "PATH"}
           "--temp-dir"  {:kind :single
                          :help "A temporary directory to use during installation of a REPO"
                          :name "TEMP"}
           "--sudo-copy" {:kind :flag
                          :short "S"
                          :help "Copy executables to the binpath using sudo"}
           :repo {:kind     :single
                  :help     "A repository that produces an executable"
                  :required false}]
   :info {:about `Build and move executables to a binpath

                 If run without REPO, the plonk subcommand will install the
                 executables declared in the current working directory's
                 project.janet file to the binpath.

                 If run with REPO, the plonk subcommand will download the REPO
                 into $HOME/.jeep/plonk (or --temp-dir), build the project and then
                 move the executables from that project to the binpath.
                 Finally, if --temp-dir was provided, the plonk subcommand will
                 remove all files added to --temp-dir.`}
   :help "Build and move executables to a binpath."
   :fn   cmd-fn})
