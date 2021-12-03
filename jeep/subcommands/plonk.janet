(import jpm/commands :as jpm/commands)
(import jpm/pm :as jpm/pm)
(import jpm/shutil :as jpm/shutil)

(import ../utilities :as util)


(defn- is-win? []
  (= :windows (os/which)))


(defn- plonk-project [exes &opt binpath]
  (default binpath (dyn :binpath))
  (if (nil? exes)
    (print "No executables to plonk")
    (each exe exes
      (def exe-name (string (exe :name) (when (is-win?) ".exe")))
      (def src (string "./build/" exe-name))
      (when (= :file (get (os/stat src) :mode))
        (jpm/shutil/copy src (string binpath "/" exe-name))))))


(defn- plonk-repo [repo &opt temp-root binpath]
  (default temp-root (if (is-win?) "%TEMP%" "/tmp" ))
  (default binpath (dyn :binpath))
  (def rng (math/rng (os/cryptorand 10)))
  (def temp-dir (string temp-root "/plonk-" (math/rng-int rng)))
  (if (not (os/mkdir temp-dir))
    (do
      (eprint "Could not create temporary directory")
      (os/exit 1))
    (defer (jpm/shutil/rimraf temp-dir)
      (setdyn :modpath temp-dir)
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
        (plonk-project (meta :jeep/exes) binpath)))))


(defn- cmd-fn [meta opts params]
  (if (params :repo)
    (plonk-repo (params :repo) (opts "temp-dir") (opts "binpath"))
    (plonk-project (meta :jeep/exes) (opts "binpath"))))


(def config
  {:rules ["--temp-dir" {:kind :single
                         :help "A temporary directory to use during installation of a REPO"
                         :name "DIR"}
           "--binpath"  {:kind :single
                         :help "The binpath to use during installation (Default: system :binpath)"
                         :name "PATH"}
           :repo {:kind     :single
                  :help     "A repository that produces an executable"
                  :required false}]
   :info {:about `Move built executables to a binpath

                 If run without REPO, the plonk subcommand will install the
                 executables declared in the current working directory's
                 project.janet file to the binpath.

                 If run with REPO, the plonk subcommand will download the REPO
                 into a temporary directory, build the project and then move
                 the executables from that project to the binpath. Finally, it
                 will remove the temporary directory.`}
   :help "Move built executables to a binpath."
   :fn   cmd-fn})
