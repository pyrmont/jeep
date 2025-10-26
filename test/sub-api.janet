(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/api :as subcmd)

(def api-doc
  ````
  # example API

  ## lib/mod1

  [bar](#bar), [foo](#foo)

  ## bar

  **function**  | [source][1]

  ```janet
  (bar)
  ```

  Does bar

  This function does bar. There are times, as difficult as it might be to
  believe, where you don't need foo and instead need bar. Time to call `bar`.

  [1]: lib/mod1.janet#L11


  ## foo

  **function**  | [source][2]

  ```janet
  (foo)
  ```

  Does foo

  This function does foo. Sometimes you really need some foo and that's
  precisely when you call `foo`.

  [2]: lib/mod1.janet#L1


  ## lib/mod2

  [baz](#baz)

  ## baz

  **function**  | [source][3]

  ```janet
  (baz)
  ```

  Does baz

  This function does baz. It does it alone, though. So alone.

  [3]: lib/mod2.janet#L1
  ````)
(def confirmation "Document generated.\n")
(def example "../res/fixtures/example")
(def example-broken "../res/fixtures/example-broken")

(deftest generate-simple-api
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:input (string example "/info.jdn")}
                       :opts {"output" "api.md"}}})
      (subcmd/run args)
      (def expect (h/add-nl api-doc 2))
      (def actual (slurp "api.md"))
      (is (== expect actual))
      (is (== confirmation out))
      (is (empty? err)))))

(deftest generate-api-to-stdout
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:input (string example "/info.jdn")}
                       :opts {"output" "-"}}})
      (subcmd/run args))) 
  (def expect (string (h/add-nl api-doc 3) "Document generated.\n"))
  (is (== expect out))
  (is (empty? err)))

(deftest generate-api-with-custom-template
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def template-path "template.mustache")
      (spit template-path "CUSTOM: {{bundle-name}}")
      (def args {:sub {:params {:input (string example "/info.jdn")}
                       :opts {"output" "api.md"
                              "template" template-path}}})
      (subcmd/run args)
      (def expect "CUSTOM: example")
      (def actual (slurp "api.md"))
      (is (== expect actual))
      (is (== confirmation out))
      (is (empty? err)))))

(deftest generate-api-with-url
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:input (string example "/info.jdn")}
                       :opts {"output" "api.md"
                              "url" "https://example.org/"}}})
      (subcmd/run args)
      (def expect (h/add-nl (string/replace-all ": lib/"
                                                ": https://example.org/lib/"
                                                api-doc)
                            2)) 
      (def actual (slurp "api.md"))
      (is (== expect actual))))
  (is (== confirmation out))
  (is (empty? err)))

(deftest generate-api-with-private-included
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args-1 {:sub {:params {:input (string example "/info.jdn")}
                         :opts {"output" "api-1.md"}}})
      (subcmd/run args-1)
      (def expect-1 (h/add-nl api-doc 2))
      (def actual-1 (slurp "api-1.md"))
      (is (== expect-1 actual-1))
      (def args-2 {:sub {:params {:input (string example "/info.jdn")}
                         :opts {"output" "api-2.md"
                                "private" true}}})
      (subcmd/run args-2)
      (def expect-2
        ````
        # example API

        ## lib/mod1

        [bar](#bar), [foo](#foo), [quux](#quux)

        ## bar

        **function**  | [source][1]

        ```janet
        (bar)
        ```

        Does bar

        This function does bar. There are times, as difficult as it might be to
        believe, where you don't need foo and instead need bar. Time to call `bar`.

        [1]: lib/mod1.janet#L11


        ## foo

        **function**  | [source][2]

        ```janet
        (foo)
        ```

        Does foo

        This function does foo. Sometimes you really need some foo and that's
        precisely when you call `foo`.

        [2]: lib/mod1.janet#L1
        
        
        ## quux
        
        **function** | **private** | [source][3]
        
        ```janet
        (quux)
        ```
        
        Does quux
        
        This function does quux. But it does it privately.
        
        [3]: lib/mod1.janet#L21


        ## lib/mod2

        [baz](#baz)

        ## baz

        **function**  | [source][4]

        ```janet
        (baz)
        ```

        Does baz

        This function does baz. It does it alone, though. So alone.

        [4]: lib/mod2.janet#L1
        ````)
      (def actual-2 (slurp "api-2.md"))
      (is (== (h/add-nl expect-2 2) actual-2))))
  (is (== (string/repeat confirmation 2) out))
  (is (empty? err)))

(deftest generate-api-with-drop-prefix
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:input (string example "/info.jdn")}
                       :opts {"output" "api.md"
                              "drop" "lib/"}}})
      (subcmd/run args)
      (def expect (h/add-nl (string/replace-all "## lib/"
                                                "## "
                                                api-doc)
                            2)) 
      (def actual (slurp "api.md"))
      (is (== expect actual))))
  (is (== confirmation out))
  (is (empty? err)))

(deftest generate-api-with-match-filter
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:input (string example "/info.jdn")}
                       :opts {"output" "api.md"
                              "match" ["lib/mod1.janet"]}}})
      (subcmd/run args)
      (def expect (->> (string/find "# lib/mod2" api-doc)
                       (dec)
                       (dec)
                       (string/slice api-doc 0))) 
      (def actual (slurp "api.md"))
      (is (== expect actual))))
  (is (== confirmation out))
  (is (empty? err)))

(deftest generate-api-with-no-match-filter
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:input (string example "/info.jdn")}
                       :opts {"output" "api.md"
                              "no-match" ["lib/mod2.janet"]}}})
      (subcmd/run args)
      (def expect (->> (string/find "# lib/mod2" api-doc)
                       (dec)
                       (dec)
                       (string/slice api-doc 0))) 
      (def actual (slurp "api.md"))
      (is (== expect actual))))
  (is (== confirmation out))
  (is (empty? err)))

(deftest error-on-missing-info-file
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:input "nonexistent.jdn"}
                       :opts {"output" "api.md"}}})
      (assert-thrown-message "file nonexistent.jdn does not exist"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-missing-source-files-key
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:input (string example-broken "/no-source.jdn")}
                       :opts {"output" "api.md"}}})
      (assert-thrown-message "info file does not have keys [:source :files]"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest error-on-invalid-source-files
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def args {:sub {:params {:input (string example-broken "/no-list.jdn")}
                       :opts {"output" "api.md"}}})
      (assert-thrown-message "info file does not have keys [:source :files]"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(run-tests!)
