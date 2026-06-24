(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/dep :as subcmd)

(deftest add-simple-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
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
      (is (== expect actual))
      (def expect-out
        ```
        adding testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest add-multiple-dependencies
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
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
      (is (== expect actual))
      (def expect-out
        ```
        adding testament...
        adding spork...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest add-dependency-orders-name-first
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      # :as sorts before :name alphabetically, so a plain alphabetical
      # ordering would put it first; by-name keeps :name at the front
      (def args {:sub {:params {:deps [`{:url "https://example.com" :as "alias" :name "mydep"}`]
                                :opts {}}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "mydep"
                          :as "alias"
                          :url "https://example.com"}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        adding mydep...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest remove-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
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
      (is (== expect actual))
      (def expect-out
        ```
        removing testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest update-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :dependencies ["testament" "spork"]))
      (os/cd path)
      (def args {:sub {:params {:deps [`{:name "testament" :url "https://github.com/pyrmont/testament"}`]}
                       :opts {"update" true}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          :url "https://github.com/pyrmont/testament"}
                         "spork"]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        updating testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest add-vendored-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:params {:deps ["testament"]}
                       :opts {"vendor" true}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :vendored ["testament"]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        adding testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest update-vendored-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :vendored ["testament" "spork"]))
      (os/cd path)
      (def args {:sub {:params {:deps [(string `{:name "testament"`
                                               ` :url "https://github.com/pyrmont/testament"`
                                               ` :prefix "vendor-dir"}`)]}
                       :opts {"update" true
                              "vendor" true}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :vendored [{:name "testament"
                      :prefix "vendor-dir"
                      :url "https://github.com/pyrmont/testament"}
                     "spork"]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        updating testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest tidy-sorts-dependencies-by-name
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      # :url is in the reverse order of :name, so sorting by anything other
      # than the dependency's name would leave the structs out of order
      (spit (string path h/sep "info.jdn")
            ```
            @{:name "test1"
              :dependencies [{:name "zed" :url "aaa"}
                             "mid"
                             {:name "alpha" :url "zzz"}]}
            ```)
      (def args {:sub {:params {:deps []}
                       :opts {"tidy" true}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "alpha" :url "zzz"}
                         "mid"
                         {:name "zed" :url "aaa"}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        tidying...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest error-on-missing-info-jdn
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
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
    (h/in-dir _
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
