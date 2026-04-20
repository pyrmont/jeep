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
   `Adds <name> to dynamic binding :test/tests.`
   :no-test
   `Adds <name> to dynamic binding :test/skips.`
   :janet
   `Sets the path for the Janet executable to use for the tests.`
   :no-result
   `Skips printing pass/fail result.`
   :warn
   `Sets the lint warning (valid levels are 'none', 'normal', 'relaxed' and 'strict').`
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
                     "--janet" {:kind  :single
                                :short "j"
                                :proxy "path"
                                :help  (helps :janet)}
                     "--no-result" {:kind  :flag
                                    :short "R"
                                    :help  (helps :no-result)}
                     "--warn" {:kind  :single
                               :short "w"
                               :proxy "level"
                               :help  (helps :warn)}
                     "----"]
             :info {:about (helps :about)}
             :help (helps :help)})

(var- no-result? false)
(var- script-count 0)
(var- failures @[])

(defn- as-str [v]
  (if (or (nil? v) (empty? v))
    "nil"
    (string "["
            (-> (map (partial string "'") v)
                (string/join " "))
            "]")))

(defn- relpath
  [path]
  (string/replace (os/cwd) "." path))

(defn- result
  [c m]
  (unless no-result?
    (print (util/colour c m))))

(defn- run-janet
  [path exe-path exe-args & dyns]
  (default exe-path (dyn :executable))
  (default exe-args [])
  (prin "running " (relpath path) "... ")
  (flush)
  (if no-result?
    (print))
  (def setup
    (if (empty? dyns)
      ""
      (do
        (def b @"")
        (each [k v] (partition 2 dyns)
          (buffer/push b (string "(setdyn :" k " " v ") ")))
        (string b))))
  (if (zero? (os/execute [exe-path ;exe-args "-m" (dyn :syspath) "-e" setup path] :p))
    (result :green "pass")
    (do
      (result :red "fail")
      (array/push failures path)))
  (++ script-count))

(defn- run-tests
  [path &named exe-path exe-args use? tests skips]
  (assert (dyn :syspath) "syspath must be set")
  (each f (sorted (os/dir path))
    (def fpath (string path util/sep f))
    (def dyn-tests (as-str tests))
    (def dyn-skips (as-str skips))
    (case (os/stat fpath :mode)
      :file
      (when (use? fpath)
        (run-janet fpath exe-path exe-args
                   :test/color? true
                   :test/runner ":jeep"
                   :test/tests dyn-tests
                   :test/skips dyn-skips))
      :directory
      (run-tests fpath :exe-path exe-path
                       :exe-args exe-args
                       :use? use?
                       :tests tests
                       :skips skips))))

(defn run
  [args &opt jeep-config]
  jeep-config # TODO: Add support for configuring via existing file
  (def params (get-in args [:sub :params] {}))
  (def opts (get-in args [:sub :opts] {}))
  (when (and (get opts "file") (get opts "no-file"))
    (error "cannot call with both --file and --no-file"))
  (when (and (get opts "test") (get opts "no-test"))
    (error "cannot call with both --test and --no-test"))
  (if (get opts "check")
    (util/local-hook :check (get params :args)))
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
  (def [ok? path]
    (protect
      (do
        (when (and util/windows? (nil? (os/stat "test")))
          (error "No such file or directory: test"))
        (os/realpath "test"))))
  (unless (or ok?)
    (error "no directory ./test"))
  (def exe-path (try (-?> (get opts "janet") os/realpath)
                     ([_] (errorf "'%s' is not a valid path" (get opts "janet")))))
  (def exe-args (if (def level (get opts "warn"))
                  ["-w" level]
                  []))
  (run-tests path :exe-path exe-path
                  :exe-args exe-args
                  :use? use?
                  :tests (get opts "test")
                  :skips (get opts "no-test"))
  (if (empty? failures)
    (print "All scripts passed.")
    (do
      (print (length failures) " of " script-count " scripts failed:")
      (each f failures
        (print "  " (string/replace (string (os/cwd)) "." f)))
      (os/exit 1))))
