(use ../deps/testament)

(import ../lib/info)

(defn- edit [src f] (info/render (f (info/parse src))))

(deftest round-trip
  (def src "@{:name \"x\"\n :deps [{:name \"a\"}]}")
  (is (== src (info/render (info/parse src)))))

(deftest add-creates-key
  (is (== "{:foo :bar\n :baz [\"qux\"]}"
          (edit "{:foo :bar}" |(info/add $ [:baz] ["qux"])))))

(deftest add-appends-to-array
  (is (== "@{:deps [{:name \"a\"}\n         {:name \"b\"}]}"
          (edit "@{:deps [{:name \"a\"}]}"
                |(info/add $ [:deps] [{:name "b"}])))))

(deftest add-merges-into-empty-dict
  (is (== "{:foo {:bar {:baz [\"qux\"]}}}"
          (edit "{:foo {:bar {}}}" |(info/add $ [:foo :bar] {:baz ["qux"]})))))

(deftest put-creates-key
  (is (== "{:foo :bar\n :baz \"qux\"}"
          (edit "{:foo :bar}" |(info/put $ [:baz] "qux")))))

(deftest put-replaces-existing
  (is (== "@{:name \"y\"}" (edit "@{:name \"x\"}" |(info/put $ [:name] "y")))))

(deftest rem-key
  (is (== "{:a 1}" (edit "{:a 1\n :b 2}" |(info/remove $ [:b])))))

(deftest rem-where
  (is (== "{:foo []}" (edit "{:foo [:bar]}" |(info/remove $ [:foo] :where :bar)))))

(deftest upd-where-to
  (is (== "{:foo [{:baz :bar\n        :qux :quux}]}"
          (edit "{:foo [:bar]}"
                |(info/update $ [:foo] :where :bar :to {:baz :bar :qux :quux})))))

(deftest upd-where-add
  (is (== "@{:deps [{:name \"a\"\n          :url \"u\"}]}"
          (edit "@{:deps [{:name \"a\"}]}"
                |(info/update $ [:deps]
                              :where (fn [x] (= "a" (get x :name)))
                              :add [:url "u"])))))

(deftest name-first-ordering
  (is (== "@{:deps [{:name \"a\"\n          :tag \"t\"\n          :url \"u\"}]}"
          (edit "@{:deps []}"
                |(info/add $ [:deps] [{:url "u" :tag "t" :name "a"}])))))

(deftest edits-mutate-in-place
  (def t (info/parse "@{:name \"x\"}"))
  (info/put t [:version] "1.0.0")
  (is (== "@{:name \"x\"\n  :version \"1.0.0\"}" (info/render t))))

(deftest errors
  (assert-thrown-message "must provide :where argument"
                         (info/update (info/parse "{:a 1}") [:name] :to 9))
  (assert-thrown-message "no match for key path '(:nope)' in metadata"
                         (info/update (info/parse "{:a 1}") [:nope] :where 1 :to 9))
  (assert-thrown-message ":where not implemented for structs/tables"
                         (info/remove (info/parse "{:a 1}") [:a] :where 1)))

(run-tests!)
