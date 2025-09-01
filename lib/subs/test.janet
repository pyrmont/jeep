(import ../util)

(def config {:rules [:args {:splat? true
                            :help   "Arguments to pass to the check hook."}
                     "--check" {:kind  :flag
                                :short "c"
                                :help  "Run the check hook."}
                     "----"
                     "--only" {:kind  :multi
                               :short "o"
                               :proxy "path"
                               :help  "Path of file to test."}
                     "--exclude" {:kind :multi
                                  :short "e"
                                  :proxy "path"
                                  :help "Path of file to exclude."}
                     "--test" {:kind  :multi
                               :short "t"
                               :proxy "name"
                               :help  "Name of test to run."}
                     "--skip" {:kind  :multi
                               :short "s"
                               :proxy "name"
                               :help  "Name of test to skip."}
                     "---"
                     "--no-passfail" {:kind  :flag
                                      :short "P"
                                      :help  "Do not print pass/fail results."}
                     "----"]
             :info {:about `Runs tests in the test directory by starting a
                           separate instance of 'janet' for each file tested.
                           The default behaviour tests every '.janet' file but
                           the user can use '--only' to test only the files
                           listed or '--exclude' to exclude the files listed.

                           If the '--test' option is set, the janet executable
                           is called for each file in the test/ directory with
                           the dynamic binding :tests set to an array of the
                           name values. So 'jeep test --test foo --test bar'
                           will cause 'janet -e "(setdyn :tests @['foo 'bar]"
                           <file>' to be run for each file tested. A similar
                           dynamic binding is set if the '--skip' option is
                           set. The design puts the responsibility on the
                           user's testing library to run or skip tests based on
                           this information.

                           If (1) the '--only' and '--exclude' options are both
                           set or (2) the '--test' and '--skip' options are both
                           set, Jeep will error. By default, the check hook is
                           not run but this can be toggled with the '--check'
                           flag.`}
             :help "Run tests for the current project."})

(var- no-results? false)
(var- script-count 0)
(var- failures @[])

(defn- relpath
  [path]
  (string/replace (os/cwd) "." path))

(defn- result
  [c m]
  (unless no-results?
    (print (util/colour c m))))

(defn- run-janet
  [path &opt args]
  (prin "running " (relpath path) "... ")
  (flush)
  (def setup
    (if (nil? args)
      ""
      (string/format "(setdyn %s @['%s])" (first args) (string/join (last args) " '"))))
  (if (zero? (os/execute ["janet" "-m" (dyn *syspath*) "-e" setup path] :p))
    (result :green "pass")
    (do
      (result :red "fail")
      (array/push failures path)))
  (++ script-count))

(defn- run-tests
  [path &named use? test skip]
  (each f (sorted (os/dir path))
    (def fpath (string path util/sep f))
    (case (os/stat fpath :mode)
      :file
      (when (use? fpath) (run-janet fpath (cond test [":tests" test] skip [":skips" skip])))
      :directory
      (run-tests fpath :use? use? :test test :skip skip))))

(defn run
  [args &opt jeep-config]
  (def opts (get-in args [:sub :opts] {}))
  (when (and (get opts "only") (get opts "exclude"))
    (error "cannot call with both '--only' and '--exclude'"))
  (when (and (get opts "test") (get opts "skip"))
    (error "cannot call with both '--test' and '--skip'"))
  (if (get opts "check")
    (util/local-hook :check))
  (set no-results? (get opts "no-passfail"))
  (def only-paths (get opts "only"))
  (def excl-paths (get opts "exclude"))
  (defn use? [path]
    (defn match? [x] (string/has-suffix? x path))
    (cond
      only-paths
      (find match? only-paths)
      excl-paths
      (not (find match? excl-paths))
      (string/has-suffix? ".janet" path)))
  (run-tests (os/realpath "test") :use? use? :test (get opts "test") :skip (get opts "skip"))
  (if (empty? failures)
    (print "All scripts passed.")
    (do
      (print (length failures) " of " script-count " scripts failed:")
      (each f failures
        (print "  " (string/replace (string (os/cwd)) "." f)))
      (os/exit 1))))
