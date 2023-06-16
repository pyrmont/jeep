(declare-project
  :name "Jeep"
  :description "A tool for developing Janet projects"
  :author "Michael Camilleri"
  :license "MIT"
  :url "https://github.com/pyrmont/jeep"
  :repo "git+https://github.com/pyrmont/jeep"
  :dependencies ["https://github.com/pyrmont/argy-bargy"
                 "https://github.com/pyrmont/documentarian"]
  :dev-dependencies ["https://github.com/pyrmont/testament"])

(declare-executable
  :name "jeep"
  :entry "jeep/cli.janet"
  :install true
  :deps ["jeep/subcommands"])

(task "dev-deps" []
  (if-let [deps ((dyn :project) :dependencies)]
    (each dep deps
      (bundle-install dep))
    (do
      (print "no dependencies found")
      (flush)))
  (if-let [deps ((dyn :project) :dev-dependencies)]
    (each dep deps
      (bundle-install dep))
    (do
      (print "no dev-dependencies found")
      (flush))))
