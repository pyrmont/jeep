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
                           "project.janet"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    created foo/
    created foo/info.jdn
    created foo/bundle/
    created foo/bundle/init.janet
    created foo/.gitignore
    created foo/LICENSE
    created foo/project.janet
    created foo/README.md
    created foo/test/
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
    created foo/
    created foo/info.jdn
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
                           "project.janet"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    created foo/
    created foo/info.jdn
    created foo/bundle/
    created foo/bundle/init.janet
    created foo/lib/
    created foo/init.janet
    created foo/.gitignore
    created foo/LICENSE
    created foo/project.janet
    created foo/README.md
    created foo/test/
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
                           "project.janet"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    created foo/
    created foo/info.jdn
    created foo/bundle/
    created foo/bundle/init.janet
    created foo/bin/
    created foo/lib/
    created foo/lib/cli.janet
    created foo/bin/foo
    created foo/.gitignore
    created foo/LICENSE
    created foo/project.janet
    created foo/README.md
    created foo/test/
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
                           "project.janet"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    created foo/
    created foo/info.jdn
    created foo/bundle/
    created foo/bundle/init.janet
    created foo/lib/
    created foo/.gitignore
    created foo/LICENSE
    created foo/project.janet
    created foo/README.md
    created foo/test/
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
                           "project.janet"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    created foo/
    created foo/info.jdn
    created foo/bundle/
    created foo/bundle/init.janet
    created foo/man/
    created foo/man/man1/
    created foo/man/man1/foo.1.predoc
    created foo/.gitignore
    created foo/LICENSE
    created foo/project.janet
    created foo/README.md
    created foo/test/
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
                           "project.janet"
                           "src"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    created foo/
    created foo/info.jdn
    created foo/bundle/
    created foo/bundle/init.janet
    created foo/src/
    created foo/.gitignore
    created foo/LICENSE
    created foo/project.janet
    created foo/README.md
    created foo/test/
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
                           "project.janet"
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
    created foo/
    created foo/info.jdn
    created foo/bundle/
    created foo/bundle/init.janet
    created foo/.gitignore
    created foo/LICENSE
    created foo/project.janet
    created foo/README.md
    created foo/test/
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
                           "project.janet"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    created foo/
    created foo/info.jdn
    created foo/bundle/
    created foo/bundle/init.janet
    created foo/lib/
    created foo/init.janet
    created foo/man/
    created foo/man/man1/
    created foo/man/man1/foo.1.predoc
    created foo/.gitignore
    created foo/LICENSE
    created foo/project.janet
    created foo/README.md
    created foo/test/
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
                           "project.janet"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))))
  (def expect-out
    ```
    created foo/
    created foo/info.jdn
    created foo/bundle.janet
    created foo/.gitignore
    created foo/LICENSE
    created foo/project.janet
    created foo/README.md
    created foo/test/
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
                           "project.janet"
                           "test"])
      (def actual-entries (sort (os/dir (string d h/sep "foo"))))
      (is (== expect-entries actual-entries))
      # Verify bundle directory contents
      (def expect-bundle-entries ["info.jdn" "init.janet"])
      (def actual-bundle-entries (sort (os/dir (string d h/sep "foo" h/sep "bundle"))))
      (is (== expect-bundle-entries actual-bundle-entries))))
  (def expect-out
    ```
    created foo/
    created foo/bundle/
    created foo/bundle/info.jdn
    created foo/bundle/init.janet
    created foo/.gitignore
    created foo/LICENSE
    created foo/project.janet
    created foo/README.md
    created foo/test/
    Bundle created.
    ```)
  (is (== (-> (h/add-nl expect-out) h/fix-seps) out))
  (is (empty? err)))

(run-tests!)
