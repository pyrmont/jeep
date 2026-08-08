(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/meta :as subcmd)

(deftest set-simple-meta
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":homepage" "https://example.org"]}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :homepage "https://example.org"}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        setting :homepage...
        Metadata changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest set-multiple-metas
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":homepage" "https://example.org" ":license" "MIT"]}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :homepage "https://example.org"
          :license "MIT"}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        setting :homepage...
        setting :license...
        Metadata changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest nil-removes-meta
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :description "foo"
                               :version "1.0.0"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":description" "nil"]}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :version "1.0.0"}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        removing :description...
        Metadata changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest set-meta
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :version "1.0.0"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":version" "2.0.0"]}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :version "2.0.0"}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        setting :version...
        Metadata changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest set-meta-to-current-value-is-a-no-op
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :version "1.0.0"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":version" "1.0.0"]}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :version "1.0.0"}
        ```)
      (is (== expect actual))
      (is (== (h/add-nl "No metadata changed.") out))
      (is (empty? err)))))

(deftest set-meta-with-bundle-dir
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :version "1.0.0"))
      (os/cd path)
      # `jeep enhance --native` leaves the info file aliased at ./info.jdn but
      # puts the bundle script in ./bundle/, so both must be able to coexist
      (os/mkdir "bundle")
      (def args {:sub {:params {:kvs [":version" "2.0.0"]}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :version "2.0.0"}
        ```)
      (is (== expect actual))
      # the update must not land in a shadow copy under ./bundle/
      (is (== nil (os/stat (string "bundle" h/sep "info.jdn") :mode)))
      (def expect-out
        ```
        setting :version...
        Metadata changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest set-meta-keeps-phrases-as-strings
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      # a value is only JDN if it parses whole, so '1.0 release' must not be
      # truncated to the number it begins with
      (def args {:sub {:params {:kvs [":description" "1.0 release"
                                      ":author" "A Programmer"]}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :description "1.0 release"
          :author "A Programmer"}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        setting :description...
        setting :author...
        Metadata changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest nil-on-absent-key-is-skipped
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":homepage" "nil"]}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        skipping :homepage, key not found
        No metadata changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest error-on-removing-name
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :version "1.0.0"))
      (os/cd path)
      # the check happens before any pair is applied, so :version is untouched
      (def args {:sub {:params {:kvs [":version" "2.0.0" ":name" "nil"]}}})
      (assert-thrown-message "cannot remove the :name key"
                             (subcmd/run args))
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :version "1.0.0"}
        ```)
      (is (== expect actual))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-setting-name-to-non-string
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":name" "42"]}}})
      (assert-thrown-message "the :name key must be a string"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-setting-name-to-empty-string
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":name" `""`]}}})
      (assert-thrown-message "the :name key must not be empty"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-odd-number-of-values
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":homepage"]}}})
      (assert-thrown-message "each key must be followed by a value"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-non-keyword-key
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:kvs ["homepage" "https://example.org"]}}})
      (assert-thrown-message "key homepage must be a keyword"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-missing-info-jdn
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def args {:sub {:params {:kvs [":homepage" "https://example.org"]}}})
      (assert-thrown-message "no info.jdn file found"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-invalid-bundle
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (spit "info.jdn" "{:version \"1.0.0\"}")
      (def args {:sub {:params {:kvs [":homepage" "https://example.org"]}}})
      (assert-thrown-message "info.jdn file must contain the :name key"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(run-tests!)
