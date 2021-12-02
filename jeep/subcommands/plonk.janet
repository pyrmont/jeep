(import jpm/shutil :as jpm/shutil)


(defn- cmd-fn [meta opts params]
  (each exe (meta :jeep/exes)
    (def exe-name (string (exe :name) (when (= :windows (os/which)) ".exe")))
    (def src (string "./build/" exe-name))
    (when (= :file (get (os/stat src) :mode))
      (jpm/shutil/copy src (string (dyn :binpath) "/" exe-name)))))


(def config
  {:info {:about `Move built executables in a Janet project to the system :binpath

                 The plonk subcommand moves built executables declared in the
                 project.janet file to the system :binpath.`}
   :help "Move built executables to the system :binpath."
   :fn   cmd-fn})
