(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/test :as subcmd)

(deftest no-dir
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def args {:sub {:opts {"no-result" true}}})
      (def msg "no directory ./test")
      (assert-thrown-message msg (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest empty-dir
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (os/mkdir "test")
      (def args {:sub {:opts {"no-result" true}}})
      (subcmd/run args)))
  (is (== (h/add-nl "All scripts passed.") out))
  (is (empty? err)))

(deftest check-dyns
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def test-file
        ```
        (defn to-str [k]
          (string/format "%j" (dyn k)))
        (spit "test/dyns_result.jdn"
              (string "{:test/runner " (to-str :test/runner)
                      " :test/tests " (to-str :test/tests)
                      " :test/skips " (to-str :test/skips)
                      " :test/color? " (to-str :test/color?) "}"))
        ```)
      (os/mkdir "test")
      (spit "test/dyns.janet" test-file)
      (def args {:sub {:opts {"no-result" true
                              "test" ["foo" "bar"]}}})
      (subcmd/run args)
      (def expect {:test/color? true
                   :test/runner :jeep
                   :test/tests ['foo 'bar]})
      (def actual (-> (slurp "test/dyns_result.jdn") parse))
      (is (== expect actual))))
  (def path (string "test" h/sep "dyns.janet"))
  (def expect (string "running ." h/sep path "... \nAll scripts passed.\n"))
  (is (== expect out))
  (is (empty? err)))

(run-tests!)
