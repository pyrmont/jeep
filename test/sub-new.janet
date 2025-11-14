(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/new :as subcmd)

(deftest create-bundle-with-no-ask
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle"
                           "info.jdn"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    adding foo/info.jdn...
    adding foo/bundle...
    adding foo/bundle/init.janet...
    adding foo/.gitignore...
    adding foo/LICENSE...
    adding foo/README.md...
    adding foo/test...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))

(deftest create-bare-bundle
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"bare" true
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries ["info.jdn"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    adding foo/info.jdn...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))
#
(deftest create-bundle-with-lib-artifact
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"library" true
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle"
                           "info.jdn"
                           "init.janet"
                           "lib"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    adding foo/info.jdn...
    adding foo/bundle...
    adding foo/bundle/init.janet...
    adding foo/lib...
    adding foo/init.janet...
    adding foo/.gitignore...
    adding foo/LICENSE...
    adding foo/README.md...
    adding foo/test...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))
#
(deftest create-bundle-with-script-artifact
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"script" true
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bin"
                           "bundle"
                           "info.jdn"
                           "lib"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    adding foo/info.jdn...
    adding foo/bundle...
    adding foo/bundle/init.janet...
    adding foo/bin...
    adding foo/lib...
    adding foo/lib/cli.janet...
    adding foo/bin/foo...
    adding foo/.gitignore...
    adding foo/LICENSE...
    adding foo/README.md...
    adding foo/test...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))
#
(deftest create-bundle-with-exe-artifact
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"executable" true
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle"
                           "info.jdn"
                           "lib"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    adding foo/info.jdn...
    adding foo/bundle...
    adding foo/bundle/init.janet...
    adding foo/lib...
    adding foo/.gitignore...
    adding foo/LICENSE...
    adding foo/README.md...
    adding foo/test...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))
#
(deftest create-bundle-with-man-artifact
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"manpage" true
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle"
                           "info.jdn"
                           "man"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    adding foo/info.jdn...
    adding foo/bundle...
    adding foo/bundle/init.janet...
    adding foo/man...
    adding foo/man/man1...
    adding foo/man/man1/foo.1.predoc...
    adding foo/.gitignore...
    adding foo/LICENSE...
    adding foo/README.md...
    adding foo/test...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))
#
(deftest create-bundle-with-nat-artifact
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"native" true
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle"
                           "info.jdn"
                           "src"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    adding foo/info.jdn...
    adding foo/bundle...
    adding foo/bundle/init.janet...
    adding foo/src...
    adding foo/.gitignore...
    adding foo/LICENSE...
    adding foo/README.md...
    adding foo/test...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))
#
(deftest create-bundle-with-custom-metadata
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"author" "Test Author"
                              "desc" "A test bundle"
                              "license" "MIT"
                              "forge" "example.org/user"
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle"
                           "info.jdn"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))
      # Verify info file contents
      (def expect-info
        ```
        {:name "foo"
         :version "DEVEL"
         :description "A test bundle"
         :author "Test Author"
         :license "MIT"
         :url "https://example.org/user/foo"
         :repo "git+https://example.org/user/foo"
         :dependencies []
         :vendored []
         :artifacts {:executables []
                     :libraries []
                     :manpages []
                     :natives []
                     :scripts []}}
        ```)
      (def actual-info (slurp (string d h/sep "foo" h/sep "info.jdn")))
      (is (== (h/add-nl expect-info) actual-info))))
  (def expect-out
    ```
    adding foo/info.jdn...
    adding foo/bundle...
    adding foo/bundle/init.janet...
    adding foo/.gitignore...
    adding foo/LICENSE...
    adding foo/README.md...
    adding foo/test...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))
#
(deftest create-bundle-with-multiple-artifacts
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"library" true
                              "manpage" true
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle"
                           "info.jdn"
                           "init.janet"
                           "lib"
                           "man"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    adding foo/info.jdn...
    adding foo/bundle...
    adding foo/bundle/init.janet...
    adding foo/lib...
    adding foo/init.janet...
    adding foo/man...
    adding foo/man/man1...
    adding foo/man/man1/foo.1.predoc...
    adding foo/.gitignore...
    adding foo/LICENSE...
    adding foo/README.md...
    adding foo/test...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))

(deftest fail-when-directory-exists
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (os/mkdir "foo")
      (def args {:sub {:params {:name "foo"}
                       :opts {"no-ask" true}}})
      (def msg "directory 'foo' already exists")
      (assert-thrown-message msg (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest create-bundle-with-alias-bundle
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"alias" ["bundle"]
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle.janet"
                           "info.jdn"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    adding foo/info.jdn...
    adding foo/bundle.janet...
    adding foo/.gitignore...
    adding foo/LICENSE...
    adding foo/README.md...
    adding foo/test...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))

(deftest create-bundle-with-no-alias-info
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:name "foo"}
                       :opts {"no-alias" ["info"]
                              "no-ask" true}}})
      (subcmd/run args)
      (def expect-entries [".gitignore"
                           "LICENSE"
                           "README.md"
                           "bundle"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))
      # Verify bundle directory contents
      (def expect-bundle-entries ["info.jdn" "init.janet"])
      (def actual-bundle-entries (sort (os/dir (string d h/sep "foo" h/sep "bundle"))))
      (is (== expect-bundle-entries actual-bundle-entries))))
  (def expect-out
    ```
    adding foo/bundle...
    adding foo/bundle/info.jdn...
    adding foo/bundle/init.janet...
    adding foo/.gitignore...
    adding foo/LICENSE...
    adding foo/README.md...
    adding foo/test...
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))

(run-tests!)
