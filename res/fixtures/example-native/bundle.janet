(import ../deps/spork/cc :as cc)

(defn build
  [_manifest &]
  (def platform (os/which))
  (def sep (get {:windows "\\" :mingw "\\" :cygwin "\\"} platform "/"))
  (def build-dir (string "_build" sep "release"))
  (def output (string build-dir sep "example-native" (module/expand-path "" ":native:")))
  (os/mkdir build-dir)
  (with-dyns [cc/*build-dir* build-dir
              cc/*build-type* :release
              cc/*visit* cc/visit-execute]
    (if (= :windows platform)
      (do
        (cc/msvc-find)
        (with-dyns [:err stderr
                    cc/*lflags* ["/NOIMPLIB"]
                    cc/*msvc-libs* [(cc/msvc-janet-import-lib)]]
          (cc/msvc-compile-and-link-shared output "src/example-native.c")
          (os/execute ["dumpbin.exe" "/dependents" output]
                      :px {:out stderr :err stderr})))
      (cc/compile-and-link-shared output "src/example-native.c"))))
