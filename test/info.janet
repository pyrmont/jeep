(use ../deps/testament)

(import ../lib/info)

# Helpers

(defn- copy [ds]
  (def res @[])
  (each el ds
    (case (type el)
      :array (array/push res (copy el))
      :string (array/push res el)))
  res)

# Tests

(deftest comment?
  (is (== true (info/comment? "# this is a comment")))
  (is (== false (info/comment? "this is not a comment"))))

(deftest eol?
  (is (== true (info/eol? "\n")))
  (is (== true (info/eol? "\r\n")))
  (is (== false (info/eol? "abc\n"))))

(deftest janet->string
  (def exp-number "37.5")
  (is (== exp-number (info/janet->string 37.5 "")))
  (def exp-struct "{:foo {:qux true\n       :bar :baz}}")
  (is (== exp-struct (info/janet->string {:foo {:bar :baz :qux true}} "")))
  (def msg-function "cannot print functions or abstract types")
  (assert-thrown-message msg-function (info/janet->string print "")))

(deftest jdn-arr->jdn-str
  (def exp-struct "{:foo :bar}")
  (is (== exp-struct (info/jdn-arr->jdn-str @[@["{" ":foo" " " ":bar" "}"]]))))

(deftest jdn-str->jdn-arr
  (def exp-struct @[@["{" ":foo" " " ":bar" "}"]])
  (is (== exp-struct (info/jdn-str->jdn-arr "{:foo :bar}") )))

(deftest whitespace?
  (is (== true (info/whitespace? " ")))
  (is (== true (info/whitespace? "\t")))
  (is (== true (info/whitespace? "\n")))
  (is (== false (info/whitespace? "a"))))

(deftest add-to
  (def arr-simple @[@["{" ":foo" " " ":bar" "}"]])
  (def exp-new-key @[@["{" ":foo" " " ":bar" "\n"
                      " " ":baz" " " @["[" `"qux"` "]"] "}"]])
  (is (== exp-new-key (info/add-to (copy arr-simple) [:baz] "qux")))
  (def exp-used-key @[@["{" ":foo" " " ":bar" "\n"
                       " " ":baz" " " @["{" ":qux" " " @["[" `"quux"` "]"] "}"]
                       "}"]])
  (is (== exp-used-key (info/add-to (copy arr-simple) [:baz :qux] "quux")))
  (def arr-complex @["# a comment" "\n"
                     @["{" ":foo" " "
                       @["{" ":bar" " "
                         @["@{" ":baz" " " @["[" `"qux"` "]"] "}"] "}"] "}"]])
  (def exp-nested @["# a comment" "\n"
                    @["{" ":foo" " "
                      @["{" ":bar" " "
                        @["@{" ":baz" " " @["[" `"qux"` "\n"
                          "                    " `"quux"` "]"] "}"] "}"] "}"]])
  (is (== exp-nested (info/add-to (copy arr-complex) [:foo :bar :baz] "quux")))
  (def msg-simple "expected indexed collection to be mapped to key :foo")
  (assert-thrown-message msg-simple (info/add-to (copy arr-simple) [:foo] "qux")))

(deftest rem-from
  (def arr-simple @[@["{" ":foo" " " @["[" ":bar" "]"] "}"]])
  (def exp-one-val @[@["{" ":foo" " " @["[" "]"] "}"]])
  (is (== exp-one-val (info/rem-from (copy arr-simple) [:foo] :bar)))
  (def arr-complex @["# a comment" "\n"
                     @["{" ":foo" " "
                       @["{" ":bar" " "
                         @["@{" ":baz" " " @["[" `"qux"` "]"] "}"] "}"] "}"]])
  (def exp-nested @["# a comment" "\n"
                    @["{" ":foo" " "
                      @["{" ":bar" " "
                        @["@{" ":baz" " " @["[" "]"] "}"] "}"] "}"]])
  (is (== exp-nested (info/rem-from (copy arr-complex) [:foo :bar :baz] "qux")))
  (def msg-no-value ":baz not in indexed collection")
  (assert-thrown-message msg-no-value (info/rem-from (copy arr-simple) [:foo] :baz))
  (def msg-no-key "key :bar missing from dictionary collection")
  (assert-thrown-message msg-no-key (info/rem-from (copy arr-simple) [:bar] :baz)))

(run-tests!)
