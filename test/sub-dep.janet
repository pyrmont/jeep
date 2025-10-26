(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/dep :as subcmd)

(deftest add-simple-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:deps ["testament"]
                                :opts {}}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :dependencies ["testament"]}
        ```)
      (is (== (h/add-nl expect) actual))
      (def expect-out
        ```
        adding testament...
        Dependencies updated.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest add-multiple-dependencies
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:deps ["testament" "spork"]
                                :opts {}}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :dependencies ["testament"
                         "spork"]}
        ```)
      (is (== (h/add-nl expect) actual))
      (def expect-out
        ```
        adding testament...
        adding spork...
        Dependencies updated.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest remove-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def path (h/make-bundle "."
                               :name "test1"
                               :dependencies ["testament" "spork"]))
      (os/cd path)
      (def args {:sub {:params {:deps ["testament"]}
                       :opts {"remove" true}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :dependencies ["spork"]}
        ```)
      (is (== (h/add-nl expect) actual))
      (def expect-out
        ```
        removing testament...
        Dependencies updated.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest add-vendored-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:deps ["testament"]}
                       :opts {"vendor" "vendor-dir"}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :vendored {"vendor-dir" ["testament"]}}
        ```)
      (is (== (h/add-nl expect) actual))
      (def expect-out
        ```
        adding testament...
        Dependencies updated.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest error-on-missing-info-jdn
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:deps ["testament"]
                                :opts {}}}})
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
      (def args {:sub {:params {:deps ["testament"]
                                :opts {}}}})
      (assert-thrown-message "info.jdn file must contain the :name key"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(run-tests!)
