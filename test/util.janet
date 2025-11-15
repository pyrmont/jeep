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
  (defn posix/os/getenv [k] (if (= "PSModulePath" k) false (os/getenv k)))
  (put env 'os/getenv @{:value posix/os/getenv})
  (def module (require "../lib/util" :fresh true :env env))
  (module/value module sym))

(defn- get-powershell [sym]
  (def env (make-env))
  (defn ps/os/which [] :windows)
  (put env 'os/which @{:value ps/os/which})
  (defn ps/os/getenv [k] (if (= "PSModulePath" k) true (os/getenv k)))
  (put env 'os/getenv @{:value ps/os/getenv})
  (def module (require "../lib/util" :fresh true :env env))
  (module/value module sym))

(defn- get-windows [sym]
  (def env (make-env))
  (defn ps/os/which [] :windows)
  (put env 'os/which @{:value ps/os/which})
  (defn ps/os/getenv [k] (if (= "PSModulePath" k) false (os/getenv k)))
  (put env 'os/getenv @{:value ps/os/getenv})
  (def module (require "../lib/util" :fresh true :env env))
  (module/value module sym))

# Tests

(deftest abspath?-posix
  (def util/abspath? (get-posix 'abspath?))
  (is (== true (util/abspath? "/absolute/path")))
  (is (== false (util/abspath? "relative/path"))))

(deftest abspath?-windows
  (def util/abspath? (get-windows 'abspath?))
  (is (== true (util/abspath? "\\absolute\\path")))
  (is (== false (util/abspath? "relative\\path"))))

(deftest apart-posix
  (def util/apart (get-posix 'apart))
  (is (== [] (util/apart "")))
  (is (== [""] (util/apart "/")))
  (is (== ["" "absolute" "path"] (util/apart "/absolute/path")))
  (is (== ["relative" "path"] (util/apart "relative/path")))
  (is (== ["relative" "path with spaces"] (util/apart `relative/"path with spaces"`)))
  (is (== ["relative" "path with escapes"] (util/apart `relative/path\ with\ escapes`)))
  (is (== ["relative"] (util/apart "relative/")))
  (assert-thrown-message "invalid path" (util/apart "invalid path")))

(deftest apart-powershell
  (def util/apart (get-powershell 'apart))
  (is (== [] (util/apart "")))
  (is (== ["C:"] (util/apart "C:\\")))
  (is (== ["C:" "absolute" "path"] (util/apart `C:\absolute\path`)))
  (is (== ["" "absolute" "path"] (util/apart `\absolute\path`)))
  (is (== ["relative" "path"] (util/apart `relative\path`)))
  (is (== ["relative" "path with spaces"] (util/apart `relative\"path with spaces"`)))
  (is (== ["relative" "path with escapes"] (util/apart "relative\\path` with` escapes")))
  (is (== ["relative"] (util/apart `relative\`)))
  (is (== [""] (util/apart "/" true)))
  (is (== ["" "absolute" "path"] (util/apart "/absolute/path" true)))
  (is (== ["relative" "path"] (util/apart "relative/path" true)))
  (assert-thrown-message "invalid path" (util/apart "invalid path")))

(deftest apart-cmd
  (def util/apart (get-windows 'apart))
  (is (== [] (util/apart "")))
  (is (== ["C:"] (util/apart "C:\\")))
  (is (== ["C:" "absolute" "path"] (util/apart `C:\absolute\path`)))
  (is (== ["" "absolute" "path"] (util/apart `\absolute\path`)))
  (is (== ["relative" "path"] (util/apart `relative\path`)))
  (is (== ["relative" "path with spaces"] (util/apart `relative\"path with spaces"`)))
  (is (== ["relative" "path with escapes"] (util/apart "relative\\path^ with^ escapes")))
  (is (== ["relative"] (util/apart `relative\`)))
  (is (== [""] (util/apart "/" true)))
  (is (== ["" "absolute" "path"] (util/apart "/absolute/path" true)))
  (is (== ["relative" "path"] (util/apart "relative/path" true)))
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
    (is (== true (util/mkdir (string "tmp" sep "foo"))))))

(deftest parent-posix
  (def util/parent (get-posix 'parent))
  (is (== "/" (util/parent "/")))
  (is (== "/absolute" (util/parent "/absolute/path")))
  (is (== "/absolute/path" (util/parent "/absolute/path/too/")))
  (is (== "/" (util/parent "/absolute/path/too/" 3)))
  (is (== "relative" (util/parent "relative/path")))
  (is (== "relative/path" (util/parent "relative/path/too/"))))

(deftest parent-windows
  (def util/parent (get-windows 'parent))
  (is (== "\\" (util/parent "C:\\")))
  (is (== "C:\\absolute" (util/parent "C:\\absolute\\path")))
  (is (== "C:\\absolute\\path" (util/parent "C:\\absolute\\path\\too\\")))
  (is (== "C:" (util/parent "C:\\absolute\\path\\too\\" 3)))
  (is (== "\\" (util/parent "\\absolute\\path\\too\\" 3)))
  (is (== "relative\\path" (util/parent "relative\\path\\too\\")))
  (is (== "relative" (util/parent "relative/path" 1 true)))
  (is (== "relative/path" (util/parent "relative/path/too/" 1 true))))

(deftest rmrf
  (defer (rmrf "tmp")
    (os/mkdir "tmp")
    (is (== nil (util/rmrf "tmp")))))

(run-tests!)
