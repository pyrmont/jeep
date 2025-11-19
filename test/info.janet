(use ../deps/testament)

(review ../lib/info)

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
  (def exp-struct "{:foo {:bar :baz\n       :qux true}}")
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

(deftest find-in
  (def arr-simple @[@["{" ":foo" " " ":bar" "}"]])
  (is (== [0 3] (info/find-in arr-simple [:foo] :dict)))
  (def arr-complex @["# a comment" "\n"
                     @["{" ":foo" " "
                       @["{" ":bar" " "
                         @["@{" ":baz" " " @["[" `"qux"` "]"] "}"] "}"] "}"]])
  (is (== [2 3 3] (info/find-in arr-complex [:foo :bar] :dict)))
  (is (== [2 3 3 3] (info/find-in arr-complex [:foo :bar :baz] :dict)))
  (is (== [2 3 3 3 1] (info/find-in arr-complex [:foo :bar :baz 0] :dict)))
  (is (== [2] (info/find-in arr-complex [:qux] :dict))))

(deftest add-to
  (def arr-simple @[@["{" ":foo" " " ":bar" "}"]])
  (def exp-new-key @[@["{" ":foo" " " ":bar" "\n"
                       " " ":baz" " " @["[" `"qux"` "]"] "}"]])
  (is (== exp-new-key (info/add-to (copy arr-simple) [:baz] ["qux"])))
  (def act-used-key (copy arr-simple))
  (def exp-used-key1 @[@["{" ":foo" " " ":bar" "\n"
                         " " ":baz" " " @["{" ":qux" " " @["[" `"quux"` "]"] "}"]
                         "}"]])
  (is (== exp-used-key1 (info/add-to act-used-key [:baz :qux] ["quux"])))
  (def exp-used-key2 @[@["{" ":foo" " " ":bar" "\n"
                         " " ":baz" " " @["{" ":qux" " " @["[" `"quux"` "]"] "\n"
                                    "       " ":corge" " " @["[" `"grault"` "]"] "}"]
                         "}"]])
  (is (== exp-used-key2 (info/add-to act-used-key [:baz :corge] ["grault"])))
  (def arr-complex @["# a comment" "\n"
                     @["{" ":foo" " "
                       @["{" ":bar" " " @["{" "}"] "}"] "}"]])
  (def act-nested (copy arr-complex))
  (def exp-nested1 @["# a comment" "\n"
                     @["{" ":foo" " "
                       @["{" ":bar" " "
                         @["{" ":baz" " " @["[" `"qux"` "]"] "}"] "}"] "}"]])
  (is (== exp-nested1 (info/add-to act-nested [:foo :bar] {:baz ["qux"]})))
  (def exp-nested2 @["# a comment" "\n"
                     @["{" ":foo" " "
                       @["{" ":bar" " "
                         @["{" ":baz" " " @["[" `"qux"` "\n"
                           "                   " `"quux"` "]"] "}"] "}"] "}"]])
  (is (== exp-nested2 (info/add-to act-nested [:foo :bar :baz] ["quux"])))
  (def msg-simple "key path '(:foo)' resolves to '\":bar\"' but expected collection")
  (assert-thrown-message msg-simple (info/add-to (copy arr-simple) [:foo] ["qux"])))

(deftest rem-from
  (def arr-simple @[@["{" ":foo" " " @["[" ":bar" "]"] "}"]])
  (def exp-one-val @[@["{" ":foo" " " @["[" "]"] "}"]])
  (is (== exp-one-val (info/rem-from (copy arr-simple) [:foo] :where :bar)))
  (def arr-complex @["# a comment" "\n"
                   @["{" ":foo" " " @["{" ":bar" " " ":baz" "\n"
                                          ":qux" @["@{" ":quux" " " @["[" `"corge"` "]"] "}"] "\n"
                                          ":grault" " " ":garply" "}"] "}"]])
  (def exp-nested1 @["# a comment" "\n"
                   @["{" ":foo" " " @["{" ":bar" " " ":baz" "\n"
                                          ":qux" @["@{" ":quux" " " @["[" "]"] "}"] "\n"
                                          ":grault" " " ":garply" "}"] "}"]])
  (is (== exp-nested1 (info/rem-from (copy arr-complex) [:foo :qux :quux] :where "corge")))
  (def exp-nested2 @["# a comment" "\n"
                   @["{" ":foo" " " @["{" ":bar" " " ":baz" "\n"
                                          ":grault" " " ":garply" "}"] "}"]])
  (is (== exp-nested2 (info/rem-from (copy arr-complex) [:foo :qux])))
  (def exp-no-change arr-complex)
  (is (== exp-no-change (info/rem-from (copy arr-complex) [:foo :qux :quux] :where :baz)) )
  (def msg-no-key ":where not implemented for structs/tables")
  (assert-thrown-message msg-no-key (info/rem-from (copy arr-complex) [:foo] :where :baz))
  (def msg-no-key "no match for key path '(:bar)' in metadata")
  (assert-thrown-message msg-no-key (info/rem-from (copy arr-simple) [:bar] :where :baz)))

(deftest upd-in
  (def arr-simple @[@["{" ":foo" " " @["[" ":bar" "]"] "}"]])
  (def exp-one-val @[@["{" ":foo" " " @["[" @["{" ":baz" " " ":bar" "\n"
                                       "        " ":qux" " " ":quux"  "}"] "]"] "}"]])
  (def act-one-val (info/upd-in (copy arr-simple) [:foo] :where :bar :to {:baz :bar :qux :quux}))
  (is (== exp-one-val act-one-val))
  (def arr-complex @["# a comment" "\n"
                   @["{" ":foo" " " @["{" ":bar" " " ":baz" "\n"
                             "       "    ":qux" " " @["@{" ":quux" " " @["[" @["{" ":corge" " " ":grault" "}"] "]"] "}"] "\n"
                             "       "    ":garply" " " ":waldo" "}"] "}"]])
  (def exp-nested1 @["# a comment" "\n"
                   @["{" ":foo" " " @["{" ":bar" " " ":baz" "\n"
                             "       "    ":qux" " " @["@{" ":quux" " " @["[" `false` "]"] "}"] "\n"
                             "       "    ":garply" " " ":waldo" "}"] "}"]])
  (defn pred-nested1 [x] (= :grault (get x :corge)))
  (is (== exp-nested1 (info/upd-in (copy arr-complex) [:foo :qux :quux] :where pred-nested1 :to false)))
  (def exp-nested2 @["# a comment" "\n"
                   @["{" ":foo" " " @["{" ":bar" " " ":baz" "\n"
                                "       " ":qux" " " @["@{" ":quux" " " @["[" @["{" ":bar" " " "true" "\n"
                                                           "                      " ":foo" " " "false" "}"] "]"] "}"] "\n"
                                "       " ":garply" " " ":waldo" "}"] "}"]])
  (def act-nested2 (info/upd-in (copy arr-complex) [:foo :qux :quux] :to [{:bar true :foo false}]))
  (is (== exp-nested2 act-nested2))
  (def exp-nested3 @["# a comment" "\n"
                   @["{" ":foo" " " @["{" ":bar" " " ":baz" "\n"
                             "       "    ":qux" " " @["@{" ":quux" " " @["[" @["{" ":corge" " " ":foobar" "}"] "]"] "}"] "\n"
                             "       "    ":garply" " " ":waldo" "}"] "}"]])
  (defn pred-nested3 [x] (= :grault (get x :corge)))
  (is (== exp-nested3 (info/upd-in (copy arr-complex) [:foo :qux :quux] :where pred-nested3 :add [:corge :foobar])))
  (def exp-nested4 @["# a comment" "\n"
                   @["{" ":foo" " " @["{" ":bar" " " ":baz" "\n"
                             "       "    ":qux" " " @["@{" ":quux" " " @["[" @["{" ":corge" " " ":grault" "\n"
                                                             "                      " ":foo" " " ":bar"  "}"] "]"] "}"] "\n"
                             "       "    ":garply" " " ":waldo" "}"] "}"]])
  (defn pred-nested4 [x] (= :grault (get x :corge)))
  (def act-nested4 (info/upd-in (copy arr-complex) [:foo :qux :quux] :where pred-nested3 :add [:foo :bar]))
  (is (== exp-nested4 act-nested4))
  (def msg-no-key "no match for key path '(:bar)' in metadata")
  (assert-thrown-message msg-no-key (info/upd-in (copy arr-simple) [:bar] :where :baz :to :qux))
  (def coll-no-key (get-in arr-complex [2 3]))
  (def msg-no-key (string/format ":where argument requires array/tuple, found %n" coll-no-key))
  (assert-thrown-message msg-no-key (info/upd-in (copy arr-complex) [:foo] :where :baz :to :qux)))

(run-tests!)
