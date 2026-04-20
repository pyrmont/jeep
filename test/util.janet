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

(run-tests!)
