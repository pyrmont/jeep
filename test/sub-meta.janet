(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/meta :as subcmd)

(deftest add-simple-meta
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":homepage" "https://example.org"]}
                       :opts {}}})
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
        adding homepage...
        Metadata changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest add-multiple-metas
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":homepage" "https://example.org" ":license" "MIT"]}
                       :opts {}}})
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
        adding homepage...
        adding license...
        Metadata changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest remove-meta
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def path (h/make-bundle "."
                               :name "test1"
                               :description "foo"
                               :version "1.0.0"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":description"]}
                       :opts {"remove" true}}})
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

(deftest update-meta
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def path (h/make-bundle "."
                               :name "test1"
                               :version "1.0.0"))
      (os/cd path)
      (def args {:sub {:params {:kvs [":version" "2.0.0"]}
                       :opts {"update" true}}})
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
        updating :version...
        Metadata changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest error-on-missing-info-jdn
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:kvs [":homepage" "https://example.org"]}
                       :opts {}}})
      (assert-thrown-message "no info.jdn file found"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-invalid-bundle
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (spit (string path h/sep "info.jdn") "{:version \"1.0.0\"}")
      (def args {:sub {:params {:kvs [":homepage" "https://example.org"]}
                       :opts {}}})
      (assert-thrown-message "info.jdn file must contain the :name key"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(run-tests!)
