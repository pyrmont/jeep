### Pretty-printing of Janet values into source text
###
### `value->source` renders a Janet value as a string of Janet source, laid out
### so that it can be spliced into an existing tree at a given indentation. The
### layout matches the conventions used for bundle metadata: collections place
### their first entry on the opening line and align subsequent entries beneath
### it, and dictionary keys are sorted (with an optional ordering hook).

(def- eol "\n")

(defn- default-order
  [dict]
  (sort (pairs dict)))

(defn value->source
  ```
  Renders the Janet value `j` as source text, indented under `indent`

  `indent` is the whitespace string already present before the value on its
  line; it is used to align any continuation lines. `key-order`, if given, is a
  function that takes a dictionary and returns its `[key value]` pairs in the
  order they should be emitted (the default sorts by key).

  Raises an error if `j` contains a function or abstract value.
  ```
  [j indent &named key-order]
  (default key-order default-order)
  (def t (type j))
  (assert (not (or (= :function t) (= :cfunction t) (= :abstract t)))
          "cannot print functions or abstract types")
  (def b @"")
  (defn dict->string [dict open close]
    (var first? true)
    (def k-indent (string indent (string/repeat " " (length open))))
    (buffer/push b open)
    (each [k v] (key-order dict)
      (if first?
        (set first? false)
        (buffer/push b eol k-indent))
      (buffer/push b (value->source k k-indent :key-order key-order))
      (if (bytes? k)
        (buffer/push b " ")
        (buffer/push b eol k-indent))
      (def extra (string/repeat " " (cond (keyword? k) (+ 2 (length k))
                                          (string? k) (+ 2 (length k))
                                          (symbol? k) (inc (length k))
                                          0)))
      (def v-indent (string k-indent extra))
      (buffer/push b (value->source v v-indent :key-order key-order)))
    (buffer/push b close))
  (defn ind->string [ind open close]
    (var first? true)
    (def el-indent (string indent (string/repeat " " (length open))))
    (buffer/push b open)
    (each el ind
      (if first?
        (set first? false)
        (buffer/push b eol el-indent))
      (buffer/push b (value->source el el-indent :key-order key-order)))
    (buffer/push b close))
  (case t
    :tuple (ind->string j "[" "]")
    :array (ind->string j "@[" "]")
    :struct (dict->string j "{" "}")
    :table (dict->string j "@{" "}")
    # default
    (buffer/push b (describe j)))
  (string b))
