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


(def jeep-src-files
  (do
    (def res @[])
    (defn get-entries [path] (->> (os/dir path) (map |(string path "/" $))))
    (def src-root "jeep")
    (def entries (get-entries src-root))
    (each e entries
      (unless (or (= "." e) (= ".." e))
        (case ((os/stat e) :mode)
          :file
          (array/push res e)

          :directory
          (array/concat entries (get-entries e)))))
    res))


(declare-executable
  :name "jeep"
  :entry "jeep/cli.janet"
  :ldflags ["-rdynamic"]
  :install true
  :deps jeep-src-files)
