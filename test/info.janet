(use ../deps/testament)

(import ../lib/info)

(defn- edit [src f] (info/render (f (info/parse src))))

(deftest round-trip
  (def src "@{:name \"x\"\n :deps [{:name \"a\"}]}")
  (is (== src (info/render (info/parse src)))))

(deftest value-returns-parsed-value
  (is (deep= @{:name "x" :deps ["a"]}
             (info/value (info/parse `@{:name "x" :deps ["a"]}`)))))

(deftest append-creates-key
  (is (== "{:foo :bar\n :baz [\"qux\"]}"
          (edit "{:foo :bar}" (fn [t] (info/append t [:baz] ["qux"]))))))

(deftest append-adds-to-array
  (is (== "@{:deps [{:name \"a\"}\n         {:name \"b\"}]}"
          (edit "@{:deps [{:name \"a\"}]}"
                (fn [t] (info/append t [:deps] [{:name "b"}]))))))

(deftest put-creates-key
  (is (== "{:foo :bar\n :baz \"qux\"}"
          (edit "{:foo :bar}" (fn [t] (info/put t [:baz] "qux"))))))

(deftest put-replaces-existing
  (is (== "@{:name \"y\"}" (edit "@{:name \"x\"}" (fn [t] (info/put t [:name] "y"))))))

(deftest put-adds-at-nested-path
  (is (== "@{:deps [{:name \"a\"\n          :url \"u\"}]}"
          (edit "@{:deps [{:name \"a\"}]}"
                (fn [t] (info/put t [:deps 0 :url] "u"))))))

(deftest put-preserves-nearby-comment
  (def src
    ```
    @{:deps [{:name "a"
              # Keep this explanation.
              :url "old"}]}
    ```)
  (def expected
    ```
    @{:deps [{:name "a"
              # Keep this explanation.
              :url "new"}]}
    ```)
  (is (== expected (edit src (fn [t] (info/put t [:deps 0 :url] "new"))))))

(deftest rem-key
  (is (== "{:a 1}" (edit "{:a 1\n :b 2}" (fn [t] (info/remove t [:b]))))))

(deftest rem-array-element
  (is (== "{:foo [:baz]}"
          (edit "{:foo [:bar :baz]}" (fn [t] (info/remove t [:foo 0]))))))

(deftest append-orders-name-first
  # :as sorts before :name alphabetically, so this fails under a plain
  # alphabetical ordering and only passes because :name is forced first
  (is (== "@{:deps [{:name \"a\"\n          :as \"x\"\n          :url \"u\"}]}"
          (edit "@{:deps []}"
                (fn [t] (info/append t [:deps] [{:url "u" :as "x" :name "a"}]))))))

(deftest edits-return-a-new-tree
  (def before (info/parse "@{:name \"x\"}"))
  (def after (info/put before [:version] "1.0.0"))
  (is (== "@{:name \"x\"}" (info/render before)))
  (is (== "@{:name \"x\"\n  :version \"1.0.0\"}" (info/render after))))

(deftest sort-orders-array
  (is (== "@{:deps [{:name \"a\"}\n         {:name \"b\"}\n         {:name \"c\"}]}"
          (edit "@{:deps [{:name \"c\"}\n         {:name \"a\"}\n         {:name \"b\"}]}"
                (fn [t] (info/sort t [:deps] :by (fn [d] (get d :name))))))))

(deftest sort-orders-dict-keys
  (is (== "@{:m {:a 2\n      :b 3\n      :c 1}}"
          (edit "@{:m {:c 1\n      :b 3\n      :a 2}}" (fn [t] (info/sort t [:m]))))))

(deftest append-rejects-non-indexed-value
  (assert-thrown-message "value to append must be an array/tuple, got :bar"
                         (info/append (info/parse "{:foo []}") [:foo] :bar)))

(run-tests!)
