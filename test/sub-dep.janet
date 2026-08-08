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
      (def args {:sub {:sub {:cmd "add"
                             :params {:deps [`{:name "testament" :url "https://example.org/testament"}`]}}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          :url "https://example.org/testament"}]}
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
      (def args {:sub {:sub {:cmd "add"
                             :params {:deps [`{:name "testament" :url "https://example.org/testament"}`
                                             `{:name "spork" :url "https://example.org/spork"}`]}}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          :url "https://example.org/testament"}
                         {:name "spork"
                          :url "https://example.org/spork"}]}
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
      (def args {:sub {:sub {:cmd "add"
                             :params {:deps [`{:url "https://example.com" :as "alias" :name "mydep"}`]}}}})
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

(deftest add-skips-existing-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir dir
      (spit "info.jdn"
            ```
            @{:name "test1"
              :dependencies [{:name "testament"
                              :url "https://example.org/testament"}]}
            ```)
      (def args {:sub {:sub {:cmd "add"
                             :params {:deps [`{:name "testament" :url "https://example.org/testament"}`
                                             `{:name "spork" :url "https://example.org/spork"}`]}}}})
      (subcmd/run args)
      (def actual (h/info-file dir))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          :url "https://example.org/testament"}
                         {:name "spork"
                          :url "https://example.org/spork"}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        skipping testament, use 'jeep dep edit' to edit existing dependencies
        adding spork...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest error-on-adding-dep-without-url
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:sub {:cmd "add"
                             :params {:deps ["testament"]}}}})
      (assert-thrown-message
        "dependency testament must be a URL or a struct/table with a :url key"
        (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-adding-struct-without-url
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:sub {:cmd "add"
                             :params {:deps [`{:name "testament"}`]}}}})
      (assert-thrown-message `dependency {:name "testament"} requires :url`
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

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
      (def args {:sub {:sub {:cmd "rem"
                             :params {:deps ["testament"]}}}})
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

(deftest remove-multiple-dependencies
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :dependencies ["testament" "spork" "honeycut"]))
      (os/cd path)
      (def args {:sub {:sub {:cmd "rem"
                             :params {:deps ["testament" "honeycut"]}}}})
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
        removing honeycut...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest edit-converts-bare-name-to-struct
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :dependencies ["testament" "spork"]))
      (os/cd path)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":url" `"https://github.com/pyrmont/testament"`]}}}})
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
        editing testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest edit-converts-bare-name-without-url
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :dependencies ["testament"]))
      (os/cd path)
      # a bare name is a legacy form, so converting it must not require a :url
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":labels" "[:dev]"]}}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          :labels [:dev]}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        editing testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest edit-takes-bare-words-as-strings
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir dir
      (spit "info.jdn"
            ```
            @{:name "test1"
              :vendored [{:name "testament"
                          :url "https://example.org/old"}]}
            ```)
      # a URL, a path and a tag all read as symbols, so they must be taken as
      # strings without the user quoting them
      (def args {:sub {:opts {"vendor" true}
                       :sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":url" "https://github.com/pyrmont/testament"
                                             ":prefix" "deps/testament"
                                             ":tag" "abc123def"]}}}})
      (subcmd/run args)
      (def actual (h/info-file dir))
      (def expect
        ```
        @{:name "test1"
          :vendored [{:name "testament"
                      :url "https://github.com/pyrmont/testament"
                      :prefix "deps/testament"
                      :tag "abc123def"}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        editing testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest edit-adds-arbitrary-keys
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir dir
      (spit "info.jdn"
            ```
            @{:name "test1"
              :dependencies [{:name "testament"
                              :url "https://github.com/pyrmont/testament"}]}
            ```)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":labels" "[:dev]" ":note" `"a note"`]}}}})
      (subcmd/run args)
      (def actual (h/info-file dir))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          :url "https://github.com/pyrmont/testament"
                          :labels [:dev]
                          :note "a note"}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        editing testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest edit-with-nil-removes-key
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir dir
      (spit "info.jdn"
            ```
            @{:name "test1"
              :dependencies [{:name "testament"
                              :url "https://github.com/pyrmont/testament"
                              :tag "drop-me"}]}
            ```)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":tag" "nil"]}}}})
      (subcmd/run args)
      (def actual (h/info-file dir))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          :url "https://github.com/pyrmont/testament"}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        editing testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest edit-dependency-to-current-value-is-a-no-op
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir dir
      (spit "info.jdn"
            ```
            @{:name "test1"
              :dependencies [{:name "testament"
                              :url "https://github.com/pyrmont/testament"}]}
            ```)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":url" `"https://github.com/pyrmont/testament"`]}}}})
      (subcmd/run args)
      (def actual (h/info-file dir))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          :url "https://github.com/pyrmont/testament"}]}
        ```)
      (is (== expect actual))
      (is (== (h/add-nl "No dependencies changed.") out))
      (is (empty? err)))))

(deftest edit-dependency-preserves-untouched-source
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir dir
      (spit "info.jdn"
            ```
            @{:name "test1"
              :dependencies [{:name "testament"
                              # Keep this explanation with the URL.
                              :url "old"
                              :tag "keep"}]}
            ```)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":url" `"new"`]}}}})
      (subcmd/run args)
      (def actual (h/info-file dir))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          # Keep this explanation with the URL.
                          :url "new"
                          :tag "keep"}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        editing testament...
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
      (def args {:sub {:opts {"vendor" true}
                       :sub {:cmd "add"
                             :params {:deps [`{:name "testament" :url "https://example.org/testament"}`]}}}})
      (subcmd/run args)
      (def actual (h/info-file path))
      (def expect
        ```
        @{:name "test1"
          :vendored [{:name "testament"
                      :url "https://example.org/testament"}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        adding testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest edit-vendored-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :vendored ["testament" "spork"]))
      (os/cd path)
      (def args {:sub {:opts {"vendor" true}
                       :sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":url" `"https://github.com/pyrmont/testament"`
                                             ":prefix" `"vendor-dir"`]}}}})
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
        editing testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest edit-dependency-with-bundle-dir
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :vendored ["testament" "spork"]))
      (os/cd path)
      # `jeep enhance --native` leaves the info file aliased at ./info.jdn but
      # puts the bundle script in ./bundle/, so both must be able to coexist
      (os/mkdir "bundle")
      (def args {:sub {:opts {"vendor" true}
                       :sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":url" `"https://github.com/pyrmont/testament"`
                                             ":prefix" `"vendor-dir"`]}}}})
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
      # the edit must not land in a shadow copy under ./bundle/
      (is (== nil (os/stat (string "bundle" h/sep "info.jdn") :mode)))
      (def expect-out
        ```
        editing testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest tidy-sorts-dependencies-by-name
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir dir
      # :url is in the reverse order of :name, so sorting by anything other
      # than the dependency's name would leave the structs out of order
      (spit "info.jdn"
            ```
            @{:name "test1"
              :dependencies [{:name "zed" :url "aaa"}
                             "mid"
                             {:name "alpha" :url "zzz"}]}
            ```)
      (def args {:sub {:sub {:cmd "tidy"}}})
      (subcmd/run args)
      (def actual (h/info-file dir))
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

(deftest edit-renames-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir dir
      (spit "info.jdn"
            ```
            @{:name "test1"
              :dependencies [{:name "testament"
                              :url "https://example.org/testament"}]}
            ```)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":name" "tester"]}}}})
      (subcmd/run args)
      (def actual (h/info-file dir))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "tester"
                          :url "https://example.org/testament"}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        editing testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest error-on-removing-dep-name
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir dir
      (spit "info.jdn"
            ```
            @{:name "test1"
              :dependencies [{:name "testament"
                              :url "https://example.org/testament"}]}
            ```)
      # the check happens before any pair is applied, so :tag is untouched
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":tag" "abc123" ":name" "nil"]}}}})
      (assert-thrown-message "cannot remove the :name key"
                             (subcmd/run args))
      (def actual (h/info-file dir))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          :url "https://example.org/testament"}]}
        ```)
      (is (== expect actual))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-editing-name-to-non-string
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :dependencies ["testament"]))
      (os/cd path)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":name" "42"]}}}})
      (assert-thrown-message "the :name key must be a string"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-adding-non-string-name
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:sub {:cmd "add"
                             :params {:deps [`{:name 42 :url "https://example.org/foo"}`]}}}})
      (assert-thrown-message
        `dependency {:name 42 :url "https://example.org/foo"} requires :name to be a string`
        (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-renaming-to-listed-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :dependencies ["testament" "spork"]))
      (os/cd path)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":name" "spork"]}}}})
      (assert-thrown-message "dependency spork is already listed"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest edit-name-to-current-value-is-allowed
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir dir
      (spit "info.jdn"
            ```
            @{:name "test1"
              :dependencies [{:name "testament"
                              :url "https://example.org/old"}]}
            ```)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":name" "testament"
                                             ":url" "https://example.org/new"]}}}})
      (subcmd/run args)
      (def actual (h/info-file dir))
      (def expect
        ```
        @{:name "test1"
          :dependencies [{:name "testament"
                          :url "https://example.org/new"}]}
        ```)
      (is (== expect actual))
      (def expect-out
        ```
        editing testament...
        Dependencies changed.
        ```)
      (is (== (h/add-nl expect-out) out))
      (is (empty? err)))))

(deftest error-on-editing-unlisted-dependency
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "." :name "test1"))
      (os/cd path)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":labels" "[:dev]"]}}}})
      (assert-thrown-message "dependency testament is not listed, add it first"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-odd-number-of-values
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :dependencies ["testament"]))
      (os/cd path)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data [":labels"]}}}})
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
      (def path (h/make-bundle "."
                               :name "test1"
                               :dependencies ["testament"]))
      (os/cd path)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"
                                      :data ["labels" "[:dev]"]}}}})
      (assert-thrown-message "key labels must be a keyword"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-edit-with-no-values
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def path (h/make-bundle "."
                               :name "test1"
                               :dependencies ["testament"]))
      (os/cd path)
      (def args {:sub {:sub {:cmd "edit"
                             :params {:dep "testament"}}}})
      (assert-thrown-message "must provide at least one key and value or set --autotag"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-missing-info-jdn
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir _
      (def args {:sub {:sub {:cmd "add"
                             :params {:deps [`{:name "testament" :url "https://example.org/testament"}`]}}}})
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
      (def args {:sub {:sub {:cmd "add"
                             :params {:deps [`{:name "testament" :url "https://example.org/testament"}`]}}}})
      (assert-thrown-message "info.jdn file must contain the :name key"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(run-tests!)
