(declare-project
  :name "Jeep"
  :description "A tool for developing Janet projects"
  :author "Michael Camilleri"
  :license "MIT"
  :url "https://github.com/pyrmont/jeep"
  :repo "git+https://github.com/pyrmont/jeep"
  :dependencies ["https://github.com/pyrmont/argy-bargy"
                 "https://github.com/janet-lang/spork"]
  :dev-dependencies ["https://github.com/pyrmont/documentarian"
                     "https://github.com/pyrmont/testament"])


(declare-executable
  :name "jeep"
  :entry "jeep/cli.janet"
  :install true)


(task "dev-deps" []
  (if-let [deps ((dyn :project) :dev-dependencies)]
    (each dep deps
      (bundle-install dep))
    (do
      (print "no dependencies found")
      (flush))))
