(use ../deps/testament)

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

# Tests

(deftest abspath?
  (is (== true (util/abspath? "/absolute/path")))
  (is (== false (util/abspath? "relative/path"))))

(deftest apart
  (is (== [] (util/apart "")))
  (is (== ["/"] (util/apart "/")))
  (is (== ["/" "absolute" "path"] (util/apart "/absolute/path")))
  (is (== [`C:\`] (util/apart `C:\`)))
  (is (== [`C:\` "absolute" "path"] (util/apart `C:\absolute/path`)))
  (is (== ["relative" "path"] (util/apart "relative/path")))
  (is (== ["relative" "path with spaces"] (util/apart `relative/"path with spaces"`)))
  (assert-thrown-message "invalid path" (util/apart "invalid path")))

(deftest colour
  (is (== "\e[32mfoo\e[0m" (util/colour :green "foo" true)))
  (is (== "\e[31mfoo\e[0m" (util/colour :red "foo" true)))
  (is (== "\e[0mfoo\e[0m" (util/colour :invalid "foo" true))))

(deftest exec
  (def [ls-r ls-w] (os/pipe))
  (def act-exit (util/exec "ls" {:err ls-w :out ls-w} "bin"))
  (ev/close ls-w)
  (def act-out (ev/read ls-r :all))
  (def exp-out "jeep\n")
  (is (== 0 act-exit))
  (is (== exp-out act-out)))

(deftest fexists?
  (is (== true (util/fexists? "info.jdn")))
  (is (== false (util/fexists? "foo"))))

(deftest mkdir
  (defer (rmrf "tmp")
    (os/mkdir "tmp")
    (is (== false (util/mkdir "tmp"))))
  (defer (rmrf "tmp")
    (os/mkdir "tmp")
    (is (== true (util/mkdir (string/join ["tmp" "foo"] sep))))))

(deftest rmrf
  (defer (rmrf "tmp")
    (os/mkdir "tmp")
    (is (== nil (util/rmrf "tmp")))))

(run-tests!)
