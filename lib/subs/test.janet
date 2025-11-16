(import ../util)

(def- helps
  {:args
   `Arguments to pass to the check hook.`
   :check
   `Run the check hook.`
   :file
   `Path of file to run. Other files will not be run.`
   :no-file
   `Path of file not to run. Other files will be run.`
   :test
   `Name of test to run. Other tests will not be run.`
   :no-test
   `Name of test not to run. Other tests will be run.`
   :no-result
   `Skips printing pass/fail result.`
   :about
   `Runs tests in the ./test directory of the bundle.`
   :help
   `Run tests for the current bundle.`})

(def config {:rules [:args {:splat? true
                            :help   (helps :args)}
                     "--check" {:kind  :flag
                                :short "c"
                                :help  (helps :check)}
                     "----"
                     "--file" {:kind  :multi
                               :short "f"
                               :proxy "path"
                               :help  (helps :file)}
                     "--no-file" {:kind :multi
                                  :short "F"
                                  :proxy "path"
                                  :help (helps :no-file)}
                     "--test" {:kind  :multi
                               :short "t"
                               :proxy "name"
                               :help  (helps :test)}
                     "--no-test" {:kind  :multi
                                  :short "T"
                                  :proxy "name"
                                  :help  (helps :no-test)}
                     "---"
                     "--no-result" {:kind  :flag
                                    :short "R"
                                    :help  (helps :no-result)}
                     "----"]
             :info {:about (helps :about)}
             :help (helps :help)})

(var- no-result? false)
(var- script-count 0)
(var- failures @[])

(defn- relpath
  [path]
  (string/replace (os/cwd) "." path))

(defn- result
  [c m]
  (unless no-result?
    (print (util/colour c m))))

(defn- run-janet
  [path & args]
  (prin "running " (relpath path) "... ")
  (flush)
  (if no-result?
    (print))
  (def setup
    (if (empty? args)
      ""
      (do
        (def b @"")
        (each [k v] (partition 2 args)
          (buffer/push b (string "(setdyn :" k " " v ") ")))
        (string b))))
  (def janet-exe (dyn :executable))
  (if (zero? (os/execute [janet-exe "-m" (dyn :syspath) "-e" setup path] :p))
    (result :green "pass")
    (do
      (result :red "fail")
      (array/push failures path)))
  (++ script-count))

(defn- run-tests
  [path &named use? test skip]
  (assert (dyn :syspath) "syspath must be set")
  (each f (sorted (os/dir path))
    (def fpath (string path util/sep f))
    (case (os/stat fpath :mode)
      :file
      (when (use? fpath)
        (run-janet fpath
                   :test/tests (if (nil? test) "nil" (string "[" (map (partial string "'") test) "]"))
                   :test/skips (if (nil? skip) "nil" (string "[" (map (partial string "'") skip) "]"))
                   :test/color? true))
      :directory
      (run-tests fpath :use? use? :test test :skip skip))))

(defn run
  [args &opt jeep-config]
  (def opts (get-in args [:sub :opts] {}))
  (when (and (get opts "file") (get opts "no-file"))
    (error "cannot call with both --file and --no-file"))
  (when (and (get opts "test") (get opts "no-test"))
    (error "cannot call with both --test and --no-test"))
  (if (get opts "check")
    (util/local-hook :check))
  (def only-paths (get opts "file"))
  (def excl-paths (get opts "no-file"))
  (set no-result? (get opts "no-result"))
  (defn use? [path]
    (defn match? [x] (string/has-suffix? x path))
    (cond
      only-paths
      (find match? only-paths)
      excl-paths
      (not (find match? excl-paths))
      (string/has-suffix? ".janet" path)))
  (run-tests (os/realpath "test") :use? use? :test (get opts "test") :skip (get opts "no-test"))
  (if (empty? failures)
    (print "All scripts passed.")
    (do
      (print (length failures) " of " script-count " scripts failed:")
      (each f failures
        (print "  " (string/replace (string (os/cwd)) "." f)))
      (os/exit 1))))
