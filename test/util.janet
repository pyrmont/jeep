(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/util)

# Helpers

(def- sep (get {:windows "\\" :cygwin "\\" :mingw "\\"} (os/which) "/"))

(defn- rmrf [path]
  (case (os/lstat path :mode)
    # --
    :directory
    (do
      (each subpath (os/dir path)
        (rmrf (string path sep subpath)))
      (os/rmdir path))
    # --
    nil
    nil # do nothing if file does not exist
    # --
    (os/rm path)))

(defn- get-posix [sym]
  (def env (make-env))
  (defn posix/os/which [] :posix)
  (put env 'os/which @{:value posix/os/which})
  (def module (require "../lib/util" :fresh true :env env))
  (module/value module sym))

(defn- get-windows [sym]
  (def env (make-env))
  (defn ps/os/which [] :windows)
  (put env 'os/which @{:value ps/os/which})
  (def module (require "../lib/util" :fresh true :env env))
  (module/value module sym))

# Tests

(deftest abspath?-posix
  (def posix-abspath? (get-posix 'abspath?))
  (is (== true (posix-abspath? "/absolute/path")))
  (is (== false (posix-abspath? "relative/path"))))

(deftest abspath?-windows
  (def win-abspath? (get-windows 'abspath?))
  (is (== true (win-abspath? "\\absolute\\path")))
  (is (== false (win-abspath? "relative\\path"))))

(deftest apart-posix
  (def posix-apart (get-posix 'apart))
  (is (== [] (posix-apart "")))
  (is (== [""] (posix-apart "/")))
  (is (== ["" "absolute" "path"] (posix-apart "/absolute/path")))
  (is (== ["" "absolute" "path"] (posix-apart "/absolute//path")))
  (is (== ["relative" "path"] (posix-apart "relative/path")))
  (is (== ["relative" "path"] (posix-apart "relative//path")))
  (is (== ["relative"] (posix-apart "relative/"))))

(deftest apart-windows
  (def win-apart (get-windows 'apart))
  (is (== [] (win-apart "")))
  (is (== ["C:"] (win-apart "C:\\")))
  (is (== ["C:" "absolute" "path"] (win-apart `C:\absolute\path`)))
  (is (== ["" "absolute" "path"] (win-apart `\absolute\path`)))
  (is (== ["" "absolute" "path"] (win-apart `\absolute\\path`)))
  (is (== ["relative" "path"] (win-apart `relative\path`)))
  (is (== ["relative" "path"] (win-apart `relative\\path`)))
  (is (== ["relative"] (win-apart `relative\`)))
  (is (== [""] (win-apart "/" true)))
  (is (== ["" "absolute" "path"] (win-apart "/absolute/path" true)))
  (is (== ["relative" "path"] (win-apart "relative/path" true))))

(deftest colour
  (is (== "\e[32mfoo\e[0m" (util/colour :green "foo" true)))
  (is (== "\e[31mfoo\e[0m" (util/colour :red "foo" true)))
  (is (== "\e[0mfoo\e[0m" (util/colour :invalid "foo" true))))

(deftest exec
  (def [exec-r exec-w] (os/pipe))
  (def act-exit (util/exec "hostname" {:err exec-w :out exec-w}))
  (ev/close exec-w)
  (def act-out (ev/read exec-r :all))
  (is (== 0 act-exit))
  (is (> (length act-out) 0)))

(deftest exec-reports-command-on-failure
  (def exe (dyn :executable))
  (def msg
    (string "command failed with non-zero exit code 7; command: "
            exe " -e (os/exit 7)"))
  (with-dyns [:janetpath exe]
    (assert-thrown-message msg
      (util/exec :janet nil "-e" "(os/exit 7)"))))

(deftest fexists?
  (is (== true (util/fexists? "info.jdn")))
  (is (== false (util/fexists? "foo"))))

(deftest mkdir
  (defer (rmrf "tmp")
    (os/mkdir "tmp")
    (is (== false (util/mkdir "tmp"))))
  (defer (rmrf "tmp")
    (os/mkdir "tmp")
    (is (== true (util/mkdir (string "tmp" sep "foo"))))))

(deftest parent-posix
  (def posix-parent (get-posix 'parent))
  (is (== "/" (posix-parent "/")))
  (is (== "/absolute" (posix-parent "/absolute/path")))
  (is (== "/absolute/path" (posix-parent "/absolute/path/too/")))
  (is (== "/" (posix-parent "/absolute/path/too/" 3)))
  (is (== "relative" (posix-parent "relative/path")))
  (is (== "relative/path" (posix-parent "relative/path/too/"))))

(deftest parent-windows
  (def win-parent (get-windows 'parent))
  (is (== "\\" (win-parent "C:\\")))
  (is (== "C:\\absolute" (win-parent "C:\\absolute\\path")))
  (is (== "C:\\absolute\\path" (win-parent "C:\\absolute\\path\\too\\")))
  (is (== "C:" (win-parent "C:\\absolute\\path\\too\\" 3)))
  (is (== "\\" (win-parent "\\absolute\\path\\too\\" 3)))
  (is (== "relative\\path" (win-parent "relative\\path\\too\\")))
  (is (== "relative" (win-parent "relative/path" 1 true)))
  (is (== "relative/path" (win-parent "relative/path/too/" 1 true))))

(deftest rimraf
  (defer (rmrf "tmp")
    (os/mkdir "tmp")
    (is (== nil (util/rmrf "tmp")))))

(deftest fetch-url-reads-local-file
  (h/in-dir _
    (spit "data.txt" "hello")
    (def url (string "file://" (os/cwd) sep "data.txt"))
    (is (== "hello" (util/fetch-url url)))))

(deftest fetch-url-returns-nil-when-missing
  (h/in-dir _
    (def url (string "file://" (os/cwd) sep "missing.txt"))
    (is (== nil (util/fetch-url url)))))

(deftest fetch-dep-announces-and-contextualizes-failures
  (def out @"")
  (def url "file::.")
  (with-dyns [:out out]
    (h/in-dir _
      (def dep {:name "example" :url url :paths 1})
      (def msg
        "failed to vendor example (file::.): expected iterable type, got 1")
      (assert-thrown-message msg (util/fetch-dep dep))))
  (is (== "vendoring .\n" out)))

(deftest fetch-dep-reports-a-path-missing-from-the-top-level
  (h/in-dir _
    (os/mkdir "example")
    (os/mkdir (string "example" sep "src"))
    (spit (string "example" sep "LICENSE") "")
    (def dep {:name "example" :url "file::example" :paths ["inc"]})
    (def msg
      (string "failed to vendor example (file::example): no path \"inc\"; "
              "the top level contains LICENSE, src"))
    (with-dyns [:out @""]
      (assert-thrown-message msg (util/fetch-dep dep)))))

(deftest fetch-dep-reports-a-path-missing-from-a-subdirectory
  (h/in-dir _
    (os/mkdir "example")
    (os/mkdir (string "example" sep "src"))
    (spit (string "example" sep "src" sep "mod.janet") "")
    (def dep {:name "example" :url "file::example" :paths ["src/nope.c"]})
    (def msg
      (string "failed to vendor example (file::example): no path \"src/nope.c\"; "
              "\"src\" contains mod.janet"))
    (with-dyns [:out @""]
      (assert-thrown-message msg (util/fetch-dep dep)))))

(deftest with-fallback-returns-first-success
  (def thunk (fn [u] (string "got " u)))
  (is (== "got x" (util/with-fallback "x" thunk))))

(deftest with-fallback-uses-alternative
  (def err @"")
  (with-dyns [:jeep-fallbacks {"bad" ["good"]}
              :err err]
    (def thunk (fn [u] (if (= u "good") :ok (error "unreachable"))))
    (is (== :ok (util/with-fallback "bad" thunk)))
    # the fallback attempt is announced on stderr
    (is (string/has-prefix? "warning: bad did not resolve, trying good" (string err)))))

(deftest with-fallback-reraises-when-exhausted
  (with-dyns [:jeep-fallbacks {"bad" ["also-bad"]}
              :err @""]
    (def thunk (fn [_] (error "original")))
    (assert-thrown-message "original" (util/with-fallback "bad" thunk))))

(deftest with-fallback-reraises-when-no-entry
  (with-dyns [:jeep-fallbacks {}]
    (def thunk (fn [_] (error "boom")))
    (assert-thrown-message "boom" (util/with-fallback "x" thunk))))

(deftest with-fallback-resolves-map-from-url
  (h/in-dir _
    (spit "fallbacks.jdn" `{"bad" ["good"]}`)
    (def url (string "file://" (os/cwd) sep "fallbacks.jdn"))
    (with-dyns [:jeep-fallbacks url
                :err @""]
      (def thunk (fn [u] (if (= u "good") :ok (error "unreachable"))))
      (is (== :ok (util/with-fallback "bad" thunk))))))

(deftest find-info-prefers-bundle-dir
  (h/in-dir _
    (os/mkdir "bundle")
    (spit "info.jdn" `@{:name "aliased"}`)
    (spit (string "bundle" sep "info.jdn") `@{:name "canonical"}`)
    (is (== (string "." sep "bundle" sep "info.jdn") (util/find-info)))))

(deftest find-info-falls-back-to-aliased-path
  (h/in-dir _
    # a bundle directory without an info file in it must not shadow ./info.jdn
    (os/mkdir "bundle")
    (spit "info.jdn" `@{:name "aliased"}`)
    (is (== (string "." sep "info.jdn") (util/find-info)))))

(deftest find-info-returns-nil-when-absent
  (h/in-dir _
    (os/mkdir "bundle")
    (is (== nil (util/find-info)))))

(deftest load-info-reads-aliased-file-alongside-bundle-dir
  (h/in-dir _
    (os/mkdir "bundle")
    (spit "info.jdn" `@{:name "aliased"}`)
    (is (== `@{:name "aliased"}` (util/load-info)))))

(deftest save-info-writes-to-file-load-info-reads
  (h/in-dir _
    (os/mkdir "bundle")
    (spit "info.jdn" `@{:name "aliased"}`)
    (util/save-info `@{:name "updated"}`)
    (is (== `@{:name "updated"}` (slurp "info.jdn")))
    # no shadow copy is created in the bundle directory
    (is (== false (util/fexists? (string "bundle" sep "info.jdn"))))))

(deftest save-info-writes-to-bundle-dir-when-canonical
  (h/in-dir _
    (os/mkdir "bundle")
    (spit (string "bundle" sep "info.jdn") `@{:name "canonical"}`)
    (util/save-info `@{:name "updated"}`)
    (is (== `@{:name "updated"}` (slurp (string "bundle" sep "info.jdn"))))
    (is (== false (util/fexists? "info.jdn")))))

(deftest save-info-creates-aliased-file-when-absent
  (h/in-dir _
    (os/mkdir "bundle")
    (util/save-info `@{:name "new"}`)
    (is (== `@{:name "new"}` (slurp "info.jdn")))))

(def- labelled-deps
  [{:name "a" :labels [:dev]}
   {:name "b" :labels [:dev :docs]}
   {:name "c" :labels [:docs]}
   {:name "d"}
   "e"])

(deftest filter-deps-without-labels-returns-everything
  (is (== labelled-deps (util/filter-deps labelled-deps)))
  (is (== labelled-deps (util/filter-deps labelled-deps :labels [] :no-labels []))))

(deftest filter-deps-with-labels-keeps-only-those-labelled
  (def names (map (fn :namer [d] (get d :name d))
                  (util/filter-deps labelled-deps :labels [:dev])))
  (is (== @["a" "b"] names)))

(deftest filter-deps-with-several-labels-matches-any
  (def names (map (fn :namer [d] (get d :name d))
                  (util/filter-deps labelled-deps :labels [:dev :docs])))
  (is (== @["a" "b" "c"] names)))

(deftest filter-deps-with-no-labels-keeps-the-unlabelled
  # a dep without :labels, and a dep listed as a bare name, are both unlabelled
  (def names (map (fn :namer [d] (get d :name d))
                  (util/filter-deps labelled-deps :no-labels [:dev])))
  (is (== @["c" "d" "e"] names)))

(deftest filter-deps-excludes-before-including
  (def names (map (fn :namer [d] (get d :name d))
                  (util/filter-deps labelled-deps
                                    :labels [:docs]
                                    :no-labels [:dev])))
  (is (== @["c"] names)))

(deftest filter-deps-matches-string-labels
  # a label written as a string is a different label from the keyword
  (def deps [{:name "kw" :labels [:dev]} {:name "str" :labels ["dev"]}])
  (is (== @[{:name "kw" :labels [:dev]}] (util/filter-deps deps :labels [:dev])))
  (is (== @[{:name "str" :labels ["dev"]}]
          (util/filter-deps deps :labels ["dev"]))))

(deftest filter-deps-treats-a-malformed-labels-key-as-unlabelled
  (def deps [{:name "a" :labels :dev} {:name "b" :labels [:dev]}])
  (is (== @[{:name "b" :labels [:dev]}] (util/filter-deps deps :labels [:dev])))
  (is (== @[{:name "a" :labels :dev}] (util/filter-deps deps :no-labels [:dev]))))

(deftest to-pairs-reads-jdn-values
  (is (== @[[:count 42]] (util/to-pairs [":count" "42"])))
  (is (== @[[:private true]] (util/to-pairs [":private" "true"])))
  (is (== @[[:kind :library]] (util/to-pairs [":kind" ":library"])))
  (is (== @[[:labels [:dev]]] (util/to-pairs [":labels" "[:dev]"])))
  (is (== @[[:paths ["a.janet" "LICENSE"]]]
          (util/to-pairs [":paths" `["a.janet" "LICENSE"]`])))
  (is (== @[[:url "quoted"]] (util/to-pairs [":url" `"quoted"`]))))

(deftest to-pairs-takes-bare-words-as-strings
  # a bare word reads as a symbol, which never belongs in an info file
  (is (== @[[:url "https://example.org/foo"]]
          (util/to-pairs [":url" "https://example.org/foo"])))
  (is (== @[[:prefix "deps/foo"]] (util/to-pairs [":prefix" "deps/foo"])))
  (is (== @[[:tag "abc123def"]] (util/to-pairs [":tag" "abc123def"])))
  (is (== @[[:license "MIT"]] (util/to-pairs [":license" "MIT"]))))

(deftest to-pairs-takes-unreadable-values-as-strings
  # more than one value, no value at all, or source that does not read
  (is (== @[[:author "A Programmer"]]
          (util/to-pairs [":author" "A Programmer"])))
  (is (== @[[:description "1.0 release"]]
          (util/to-pairs [":description" "1.0 release"])))
  (is (== @[[:version "1.0.0"]] (util/to-pairs [":version" "1.0.0"])))
  (is (== @[[:date "2026-08-09"]] (util/to-pairs [":date" "2026-08-09"])))
  (is (== @[[:note ""]] (util/to-pairs [":note" ""]))))

(deftest to-pairs-reads-nil-as-nil
  (def pairs (util/to-pairs [":tag" "nil"]))
  (is (== 1 (length pairs)))
  (is (== :tag (first (first pairs))))
  (is (== nil (last (first pairs)))))

(deftest to-pairs-reads-multiple-pairs
  (is (== @[[:a 1] [:b "two"]] (util/to-pairs [":a" "1" ":b" "two"]))))

(deftest to-pairs-errors-on-bad-input
  (assert-thrown-message "each key must be followed by a value"
                         (util/to-pairs [":a"]))
  (assert-thrown-message "key a must be a keyword"
                         (util/to-pairs ["a" "1"]))
  (assert-thrown-message "key \"a\" must be a keyword"
                         (util/to-pairs [`"a"` "1"])))

(run-tests!)
