(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/quickbin :as subcmd)

(def confirmation "Executable created.\n")

(deftest create-executable
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def script-path "test-script.janet")
      (spit script-path
        ```
        (defn main [& args] (os/exit 37))
        ```)
      (def bin "test-exe")
      (def args {:sub {:params {:script script-path
                                :exe bin}}})
      (subcmd/run args)
      (is (os/stat bin))
      (is (== 37 (os/execute ["./test-exe"] :p)))))
  (is (string/has-suffix? confirmation out))
  (is (empty? err)))

(run-tests!)
