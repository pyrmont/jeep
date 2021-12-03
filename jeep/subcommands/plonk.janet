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


(defn- plonk-repo [repo &opt temp-root]
  (default temp-root (if (is-win?) "%TEMP%" "/tmp" ))
  (def temp-dir (string temp-root "/plonk-" (math/round (* 100 (math/random)))))
  (if (not (os/mkdir temp-dir))
    (do
      (eprint "Could not create temporary directory")
      (os/exit 1))
    (defer (jpm/shutil/rimraf temp-dir)
      (setdyn :modpath temp-dir)
      (def binpath (dyn :binpath))
      # (jpm/commands/set-tree temp-dir)
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
    (plonk-repo (params :repo) (opts "temp-dir"))
    (plonk-project (meta :jeep/exes))))


(def config
  {:rules ["--temp-dir" {:kind :single
                         :help "A temporary directory to use during installation"
                         :name "DIR"}
           :repo {:kind     :single
                  :help     "A repository that produces an executable"
                  :required false}]
   :info {:about `Move built executables to the system :binpath

                 If run without REPO, the plonk subcommand will install the
                 executables declared in the current working directory's
                 project.janet file to the system :binpath.

                 If run with a REPO, the plonk subcommand will download the
                 REPO into a temporary directory, build the project and then
                 move the executables from that project to the system :binpath.
                 Finally, it will remove the temporary directory.`}
   :help "Move built executables to the system :binpath."
   :fn   cmd-fn})
