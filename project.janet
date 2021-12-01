(declare-project
  :name "Jeep"
  :description "A tool for developing Janet projects"
  :author "Michael Camilleri"
  :license "MIT"
  :url "https://github.com/pyrmont/jeep"
  :repo "git+https://github.com/pyrmont/jeep"
  :dependencies ["https://github.com/janet-lang/jpm"
                 "https://github.com/janet-lang/spork"]
  :jeep/tree ".jeep"
  :jeep/dev-dependencies ["https://github.com/pyrmont/documentarian"
                          "https://github.com/pyrmont/testament"])


(declare-executable
  :name "jeep"
  :entry "jeep/cli.janet"
  :install true)
