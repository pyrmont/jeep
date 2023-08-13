(use testament)
(use ../test-utils)


(deftest cli-no-args
  (def msg `Usage: jeep [--tree <path>] [--local] <subcommand> [<args>]

           A tool for developing Janet projects

           The following global options are available:

                --tree <path>    Use directory <path> for dependencies.
            -l, --local          Use directory 'jpm_tree' for dependencies.
            -h, --help           Show this help message.

           The following subcommands are available:

            doc    Generate API documentation.

           For more information on each subcommand, type 'jeep help <subcommand>'.`)
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
