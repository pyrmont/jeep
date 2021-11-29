(import jpm/config :as jpm/config)
(import jpm/pm :as jpm/pm)
(import jpm/rules :as jpm/rules)


(defn- cmd-fn [meta opts params]
  (defn run-tests [&opt root-directory build-directory]
    (def monkey-patch
      (string
        `(setdyn :jeep/tests `
        (string/format "%j" (params :tests))
        `)
        (defn- check-is-dep [x] (unless (or (string/has-prefix? "/" x) (string/has-prefix? "." x)) x))
        (array/push module/paths  ["./build/:all:`
        (jpm/config/dyn:modext)
        `" :native check-is-dep])`))
    (def environ (merge-into (os/environ) {"JANET_PATH" (jpm/config/dyn:modpath)}))
    (var errors-found 0)
    (defn dodir
      [dir bdir]
      (each sub (sort (os/dir dir))
        (def ndir (string dir "/" sub))
        (case (os/stat ndir :mode)
          :directory
          (dodir ndir bdir)

          :file
          (when (string/has-suffix? ".janet" ndir)
            (print "running " ndir "...")
            (flush)
            (def result
              (os/execute
                [(jpm/config/dyn:janet) "-e" monkey-patch ndir]
                :ep
                environ))
            (when (not= 0 result)
              (++ errors-found)
              (eprintf "non-zero exit code in %s: %d" ndir result))))))
    (dodir "test" "build")
    (if (zero? errors-found)
      (print "All tests passed.")
      (do
        (printf "Failing test scripts: %d" errors-found)
        (os/exit 1)))
    (flush))

  (jpm/pm/import-rules "./project.janet" false)
  (def rules (jpm/rules/getrules))
  (def task (rules "test"))
  (put (task :recipe) 0 run-tests)

  (jpm/pm/do-rule "test"))


(def config
   {:rules [:tests  {:rest true
                     :help `One or more tests to run.`}]
    :info  {:about  `Run tests for Janet projects

                    The test subcommand works similarly to jpm's 'test' task.
                    It allows a user to provide one or more TESTS.  Each test
                    file is run with the dynamic binding :jpm/tests set to the
                    value of TESTS.`}
    :help  "Run tests."
    :fn    cmd-fn})
