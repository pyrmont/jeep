#!/usr/bin/env janet

(import ./lib/util)

(defn main
  [& args]
  (def deps-dir "deps")
  (unless (= :directory (os/stat deps-dir :mode))
    (util/vendor-deps deps-dir))
  )
