(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/prep :as subcmd)

(def confirmation "Preparations completed.\n")
(def fdir "../res/fixtures")
(def nl "\n")

(deftest prep-with-no-bundle-script
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-no-script"}
        ```)
      (spit "info.jdn" info-file)
      (def args {:sub {:params {:args []}}})
      (def msg "failed to load bundle script; use --no-hook to skip loading")
      (assert-thrown-message msg (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

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
  (var dir nil)
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (set dir d)
      (def syspath (h/make-syspath "."))
      (def path (h/make-bundle "." :name "test"
                                   :dependencies ["file::../../res/fixtures/example"]))
      (os/cd path)
      (def args {:sub {:params {:profile "system"}
                       :opts {}}})
      (subcmd/run args)
      (is (== [".cache" "bundle" "mod1.janet" "mod2.janet"] (sorted (os/dir syspath))))))
  (def expect-out
    (string "running hook install for bundle example" nl
            "add " dir h/sep "_system" h/sep "mod1.janet" nl
            "add " dir h/sep "_system" h/sep "mod2.janet" nl
            "installed example" nl
            confirmation))
  (is (== expect-out out))
  (is (empty? err)))

(deftest prep-system-profile-with-no-deps-flag
  (def out @"")
  (def err @"")
  (var dir nil)
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (set dir d)
      (def syspath (h/make-syspath "."))
      (def path (h/make-bundle "." :name "test"
                                   :dependencies ["file::../../res/fixtures/example"]))
      (os/cd path)
      (def args {:sub {:params {:profile "system"}
                       :opts {"no-deps" true}}})
      (subcmd/run args)
      (is (== ["bundle"] (sorted (os/dir syspath))))))
  (is (== confirmation out))
  (is (empty? err)))

(deftest prep-build-profile
  (def out @"")
  (def err @"")
  (var dir nil)
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (set dir d)
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
  (def expect-out
    (string "vendoring essential build files into bundle" nl
            "  copying LICENSE to bundle" h/sep "spork" h/sep "LICENSE" nl
            "  copying build-rules.janet to bundle" h/sep "spork" h/sep "build-rules.janet" nl
            "  copying cc.janet to bundle" h/sep "spork" h/sep "cc.janet" nl
            "  copying cjanet.janet to bundle" h/sep "spork" h/sep "cjanet.janet" nl
            "  copying declare-cc.janet to bundle" h/sep "spork" h/sep "declare-cc.janet" nl
            "  copying path.janet to bundle" h/sep "spork" h/sep "path.janet" nl
            "  copying pm-config.janet to bundle" h/sep "spork" h/sep "pm-config.janet" nl
            "  copying sh.janet to bundle" h/sep "spork" h/sep "sh.janet" nl
            "  copying stream.janet to bundle" h/sep "spork" h/sep "stream.janet" nl
            confirmation))
  (is (== expect-out out))
  (is (empty? err)))

(deftest prep-legacy-vendor-profile
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
  (def origin (string ".." h/sep ".." h/sep "res" h/sep "fixtures" h/sep "example"))
  (def expect-out
    (string "warning: use of structs with :vendored is deprecated, "
            "refer to the man page for more information" nl
            "warning: use of :files is deprecated in vendored dependencies" nl
            "vendoring " origin nl
            "  copying " origin h/sep "lib" h/sep ". to deps" h/sep "example" h/sep "lib" nl
            confirmation))
  (is (== expect-out out))
  (is (empty? err)))

(deftest prep-vendor-profile-with-prefix
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def dep
        {:name "test"
         :vendored [
            {:name "example"
             :url "file::../../res/fixtures/example"
             :prefix "deps/example"
             :paths ["lib"]}]})
      (def path (h/make-bundle "." ;(kvs dep)))
      (os/cd path)
      (def args {:sub {:params {:profile "vendor"}}})
      (subcmd/run args)
      (def libpath (string "deps" h/sep "example" h/sep "lib"))
      (is (== ["mod1.janet" "mod2.janet"] (sorted (os/dir libpath))))))
  (def origin (string ".." h/sep ".." h/sep "res" h/sep "fixtures" h/sep "example"))
  (def expect-out
    (string "vendoring " origin nl
            "  copying " origin h/sep "lib" h/sep ". to deps" h/sep "example" h/sep "lib" nl
            confirmation))
  (is (== expect-out out))
  (is (empty? err)))

(deftest prep-vendor-profile-with-prefix-and-renaming
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def dep
        {:name "test"
         :vendored [
            {:name "example"
             :url "file::../../res/fixtures/example"
             :prefix "deps/example"
             :paths [["lib/mod1.janet" "foo/"]
                     ["lib/mod2.janet" "foo/mod2.janet"]]}]})
      (def path (h/make-bundle "." ;(kvs dep)))
      (os/cd path)
      (def args {:sub {:params {:profile "vendor"}}})
      (subcmd/run args)
      (def libpath (string "deps" h/sep "example" h/sep "foo"))
      (is (== ["mod1.janet" "mod2.janet"] (sorted (os/dir libpath))))))
  (def origin (string ".." h/sep ".." h/sep "res" h/sep "fixtures" h/sep "example"))
  (def expect-out
    (string "vendoring " origin nl
            "  copying " origin h/sep "lib" h/sep "mod1.janet to deps" h/sep "example" h/sep "foo" h/sep nl
            "  copying " origin h/sep "lib" h/sep "mod2.janet to deps" h/sep "example" h/sep "foo" h/sep "mod2.janet" nl
            confirmation))
  (is (== expect-out out))
  (is (empty? err)))

(deftest prep-vendor-profile-with-no-prefix
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def dep
        {:name "test"
         :vendored [
            {:name "example"
             :url "file::../../res/fixtures/example"
             :paths ["lib"]}]})
      (def path (h/make-bundle "." ;(kvs dep)))
      (os/cd path)
      (def args {:sub {:params {:profile "vendor"}}})
      (subcmd/run args)
      (def libpath (string "lib"))
      (is (== ["mod1.janet" "mod2.janet"] (sorted (os/dir libpath))))))
  (def origin (string ".." h/sep ".." h/sep "res" h/sep "fixtures" h/sep "example"))
  (def expect-out
    (string "vendoring " origin nl
            "  copying " origin h/sep "lib" h/sep ". to ." h/sep "lib" nl
            confirmation))
  (is (== expect-out out))
  (is (empty? err)))

(run-tests!)
