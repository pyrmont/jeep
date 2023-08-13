(use testament)


(defn run-cmd [& args]
  (def cmd "./build/jeep")
  (def env {"JEEP_SUBCMDS" "" "TERM" (os/getenv "TERM") :out :pipe :err :pipe})
  (def proc (os/spawn [cmd ;args] :ep env))
  (def out (get proc :out))
  (def err (get proc :err))
  (def out-buf @"")
  (def err-buf @"")
  (var status 0)
  (ev/gather
    (:read out :all out-buf)
    (:read err :all err-buf)
    (set status (:wait proc)))
  {:err err-buf
   :out out-buf
   :status status})


(deftest cli-no-args
  (def msg `Usage: jeep [--tree <path>] [--local]

           A tool for developing Janet projects

           The following global options are available:

                --tree <path>    Use directory <path> for dependencies.
            -l, --local          Use directory 'jpm_tree' for dependencies.
            -h, --help           Show this help message.`)
  (def expect {:err "" :out (string msg "\n") :status 1})
  (def actual (run-cmd))
  (is (== expect actual)))


# (deftest cli-jpm-passthru
#   (def msg `build
#             └─build/jeep
#                ├─jeep/cli.janet
#                └─jeep/subcommands`)
#   (def expect {:err "" :out (string msg "\n") :status 0})
#   (def actual (run-cmd "rule-tree" "build"))
#   (is (== expect actual)))


(run-tests!)
