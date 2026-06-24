(use ../deps/testament)

(import ../lib/info)

(defn- edit [src f] (info/render (f (info/parse src))))

(deftest round-trip
  (def src "@{:name \"x\"\n :deps [{:name \"a\"}]}")
  (is (== src (info/render (info/parse src)))))

(deftest add-creates-key
  (is (== "{:foo :bar\n :baz [\"qux\"]}"
          (edit "{:foo :bar}" (fn [t] (info/add t [:baz] ["qux"]))))))

(deftest add-appends-to-array
  (is (== "@{:deps [{:name \"a\"}\n         {:name \"b\"}]}"
          (edit "@{:deps [{:name \"a\"}]}"
                (fn [t] (info/add t [:deps] [{:name "b"}]))))))

(deftest add-merges-into-empty-dict
  (is (== "{:foo {:bar {:baz [\"qux\"]}}}"
          (edit "{:foo {:bar {}}}" (fn [t] (info/add t [:foo :bar] {:baz ["qux"]}))))))

(deftest put-creates-key
  (is (== "{:foo :bar\n :baz \"qux\"}"
          (edit "{:foo :bar}" (fn [t] (info/put t [:baz] "qux"))))))

(deftest put-replaces-existing
  (is (== "@{:name \"y\"}" (edit "@{:name \"x\"}" (fn [t] (info/put t [:name] "y"))))))

(deftest rem-key
  (is (== "{:a 1}" (edit "{:a 1\n :b 2}" (fn [t] (info/remove t [:b]))))))

(deftest rem-where
  (is (== "{:foo []}" (edit "{:foo [:bar]}" (fn [t] (info/remove t [:foo] :where :bar))))))

(deftest upd-where-to
  (is (== "{:foo [{:baz :bar\n        :qux :quux}]}"
          (edit "{:foo [:bar]}"
                (fn [t] (info/update t [:foo] :where :bar :to {:baz :bar :qux :quux}))))))

(deftest upd-where-add
  (is (== "@{:deps [{:name \"a\"\n          :url \"u\"}]}"
          (edit "@{:deps [{:name \"a\"}]}"
                (fn [t] (info/update t [:deps]
                                     :where (fn [x] (= "a" (get x :name)))
                                     :add [:url "u"]))))))

(deftest name-first-ordering
  # :as sorts before :name alphabetically, so this fails under a plain
  # alphabetical ordering and only passes because :name is forced first
  (is (== "@{:deps [{:name \"a\"\n          :as \"x\"\n          :url \"u\"}]}"
          (edit "@{:deps []}"
                (fn [t] (info/add t [:deps] [{:url "u" :as "x" :name "a"}]))))))

(deftest edits-mutate-in-place
  (def t (info/parse "@{:name \"x\"}"))
  (info/put t [:version] "1.0.0")
  (is (== "@{:name \"x\"\n  :version \"1.0.0\"}" (info/render t))))

(deftest has-detects-key
  (def t (info/parse "@{:name \"x\"}"))
  (is (info/has? t [:name]))
  (is (not (info/has? t [:nope]))))

(deftest sort-orders-array
  (is (== "@{:deps [{:name \"a\"}\n         {:name \"b\"}\n         {:name \"c\"}]}"
          (edit "@{:deps [{:name \"c\"}\n         {:name \"a\"}\n         {:name \"b\"}]}"
                (fn [t] (info/sort t [:deps] :by (fn [d] (get d :name))))))))

(deftest sort-orders-dict-keys
  (is (== "@{:m {:a 2\n      :b 3\n      :c 1}}"
          (edit "@{:m {:c 1\n      :b 3\n      :a 2}}" (fn [t] (info/sort t [:m]))))))

(deftest add-rejects-duplicate-key
  (assert-thrown-message "key :name already present at key path (:deps 0); use put to replace"
                         (info/add (info/parse "@{:deps [{:name \"a\"}]}")
                                   [:deps 0] {:name "b"})))

(deftest errors
  (assert-thrown-message "must provide :where argument"
                         (info/update (info/parse "{:a 1}") [:name] :to 9))
  (assert-thrown-message "no match for key path '(:nope)' in metadata"
                         (info/update (info/parse "{:a 1}") [:nope] :where 1 :to 9))
  (assert-thrown-message ":where not implemented for structs/tables"
                         (info/remove (info/parse "{:a 1}") [:a] :where 1)))

(run-tests!)
