(import ../deps/spork/cc :as cc)

(defn build
  [_manifest &]
  (def build-dir (string "_build" (get {:windows "\\" :mingw "\\" :cygwin "\\"} (os/which) "/") "release"))
  (os/mkdir build-dir)
  (with-dyns [cc/*build-dir* build-dir
              cc/*build-type* :release
              cc/*visit* cc/visit-execute]
    (cc/compile-and-link-shared
      (string build-dir (get {:windows "\\" :mingw "\\" :cygwin "\\"} (os/which) "/") "example-native" (module/expand-path "" ":native:"))
      "src/example-native.c")))
