(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/prep :as subcmd)

(def confirmation "Preparations completed.\n")
(def fdir "../res/fixtures")

(deftest prep-default-profile
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def path (h/make-bundle "." :name "test-prep-default"))
      (os/cd path)
      (def args {:sub {}})
      (subcmd/run args)
      (is (== ["bundle"] (sorted (os/dir syspath))))))
  (is (== confirmation out))
  (is (empty? err)))

(deftest prep-system-profile-no-deps
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def path (h/make-bundle "." :name "test-prep-default"))
      (os/cd path)
      (def args {:sub {:params {:profile "system"}
                       :opts {}}})
      (subcmd/run args)
      (is (== ["bundle"] (sorted (os/dir syspath))))))
  (is (== confirmation out))
  (is (empty? err)))

(deftest prep-system-profile-with-deps
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def path (h/make-bundle "." :name "test"
                                   :dependencies ["file::../../res/fixtures/example"]))
      (os/cd path)
      (def args {:sub {:params {:profile "system"}
                       :opts {}}})
      (subcmd/run args)
      (is (== [".cache" "bundle" "mod1.janet" "mod2.janet"] (sorted (os/dir syspath))))))
  (is (string/has-suffix? confirmation out))
  (is (empty? err)))

(deftest prep-system-profile-with-no-deps-flag
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def path (h/make-bundle "." :name "test"
                                   :dependencies ["file::../../res/fixtures/example"]))
      (os/cd path)
      (def args {:sub {:params {:profile "system"}
                       :opts {"no-deps" true}}})
      (subcmd/run args)
      (is (== ["bundle"] (sorted (os/dir syspath))))))
  (is (string/has-suffix? confirmation out))
  (is (empty? err)))

(deftest prep-build-profile
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def path (h/make-bundle "." :name "test"))
      (os/cd path)
      (def args {:sub {:params {:profile "build"}}})
      (subcmd/run args)
      (def expect
        ["LICENSE"
         "build-rules.janet"
         "cc.janet"
         "cjanet.janet"
         "declare-cc.janet"
         "path.janet"
         "pm-config.janet"
         "sh.janet"
         "stream.janet"])
      (is (== expect (sorted (os/dir (string "bundle" h/sep "spork")))))))
  (is (string/has-suffix? confirmation out))
  (is (empty? err)))

(deftest prep-vendor-profile
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def dep
        {:name "test"
         :vendored {
          "deps" [
            {:name "example"
             :prefix "example"
             :url "file::../../res/fixtures/example"
             :files ["lib"]}]}})
      (def path (h/make-bundle "." ;(kvs dep)))
      (os/cd path)
      (def args {:sub {:params {:profile "vendor"}}})
      (subcmd/run args)
      (def libpath (string "deps" h/sep "example" h/sep "lib"))
      (is (== ["mod1.janet" "mod2.janet"] (sorted (os/dir libpath))))))
  (is (string/has-suffix? confirmation out))
  (is (empty? err)))

(run-tests!)
