(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/enhance :as subcmd)

(def confirmation "Bundle enhanced.n")
(def example-new "../res/fixtures/example")
(def example-old "../res/fixtures/example-old")
(def example-broken "../res/fixtures/example-broken")

(deftest enhance-project
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (h/copy-bundle example-old d)
      (def args {:sub {:opts {"no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle"
                           "info.jdn"
                           "lib"
                           "project.janet"
                           "project.janet.original"
                           "test"])
      (def actual-entries (sort (os/dir d)))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    moved ./project.janet to ./project.janet.original
    created ./info.jdn
    created ./bundle/
    created ./bundle/init.janet
    created ./project.janet
    Bundle enhanced.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))

(deftest enhance-project-without-aliases
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (h/copy-bundle example-old d)
      (def args {:sub {:opts {"no-alias" ["info"]
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle"
                           "lib"
                           "project.janet"
                           "project.janet.original"
                           "test"])
      (def actual-entries (sort (os/dir d)))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    moved ./project.janet to ./project.janet.original
    created ./bundle/
    created ./bundle/info.jdn
    created ./bundle/init.janet
    created ./project.janet
    Bundle enhanced.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))

(deftest enhance-project-failure
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (h/copy-bundle example-old d)
      (def args {:sub {:opts {"no-ask" true}}})
      (spit "project.janet.original" "")
      (def msg "cannot back up ./project.janet to ./project.janet.original, file exists")
      (assert-thrown-message (h/fix-seps msg) (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(run-tests!)
