### Data-level editing of Janet source
###
### These functions treat a parsed tree as the Janet *value* it represents and
### let you read and edit it by key path, the way `get-in` / `put-in` /
### `update-in` work on live data — except the surrounding source (whitespace,
### comments, the formatting of untouched entries) is preserved.
###
### A `path` is a tuple of segments. Within a struct or table a segment is a
### key; within a tuple or array it is a 0-based index. New and replacement
### values are rendered with `format/value->source`; an optional `:key-order`
### hook (a function from a dictionary to its ordered `[key value]` pairs) sets
### the order in which dictionary keys are emitted.

(import ./parser)
(import ./zipper :as z)
(import ./format :as f)

# Node classification

(def- dict-kinds {:struct true :table true})
(def- ind-kinds {:tuple true :array true :bracket-tuple true :bracket-array true})
(def- open-delims
  {:struct "{" :table "@{"
   :bracket-tuple "[" :bracket-array "@["
   :tuple "(" :array "@("})

(defn- dict-node? [node] (truthy? (get dict-kinds (first node))))
(defn- ind-node? [node] (truthy? (get ind-kinds (first node))))
(defn- trivia-node? [node] (case (first node) :whitespace true :comment true false))
(defn- non-trivia? [node] (not (trivia-node? node)))

# Helpers

(defn- spaces [n] (string/repeat " " (max 0 n)))

(defn- ws [text] [:whitespace text])

(defn- node->value
  [node]
  (parse (parser/render node)))

(defn- default-order [dict] (sort (pairs dict)))

(defn- order-pairs
  [dict key-order]
  (if key-order (key-order dict) (default-order dict)))

(defn- value->node
  ```
  Converts `v` into a single node, with continuation lines indented under `indent`
  ```
  [v indent key-order]
  (def src (f/value->source v indent :key-order key-order))
  (in (parser/parse src) 1))

# Navigation

(defn- seek-in
  ```
  Returns the value z-location for segment `seg` within the collection at
  `coll-zloc`, or nil if it is absent
  ```
  [coll-zloc seg]
  (def n (z/node coll-zloc))
  (cond
    (dict-node? n)
    (do
      (var kz (z/down-skip coll-zloc))
      (var found nil)
      (while kz
        (if (= seg (z/value kz))
          (do (set found (z/right-skip kz)) (set kz nil))
          (set kz (z/right-skip (z/right-skip kz)))))
      found)
    (ind-node? n)
    (do
      (var ez (z/down-skip coll-zloc))
      (var i 0)
      (while (and ez (< i seg))
        (set ez (z/right-skip ez))
        (++ i))
      ez)
    # not a collection
    nil))

(defn- top
  ```
  Returns the z-location of the top-level form in `tree`
  ```
  [tree]
  (z/down-skip (z/zip tree)))

(defn- seek
  ```
  Returns the value z-location at `path`, or nil if any segment is absent
  ```
  [tree path]
  (var cur (top tree))
  (each seg path
    (if (nil? cur) (break))
    (set cur (seek-in cur seg)))
  cur)

# Collection mutators (operate on a collection z-location, return a new one)

(defn- content-col
  ```
  Returns the 1-based column at which entries of collection node `n` begin

  Derived from the collection's own position and leading trivia rather than its
  first child's stored column, so it stays correct after edits insert children
  (which carry no real source location).
  ```
  [cz]
  (def n (z/node cz))
  (def kids (slice n 1))
  (def lead (take-while trivia-node? kids))
  (def lead-text (string/join (map |(in $ 1) lead)))
  (def lines (string/split "\n" lead-text))
  (if (one? (length lines))
    (+ (z/column-of cz) (length (get open-delims (first n))) (length lead-text))
    (inc (length (last lines)))))

(defn- dict-add-entries
  [cz pairs key-order]
  (def n (z/node cz))
  (def kids (slice n 1))
  (def col (content-col cz))
  (def k-indent (spaces (dec col)))
  (var first? (not (find non-trivia? kids)))
  (def new-kids (array ;kids))
  (each [k v] pairs
    (def k-str (f/value->source k "" :key-order key-order))
    (def k-node (in (parser/parse k-str) 1))
    (def v-node (value->node v (spaces (+ (dec col) (length k-str) 1)) key-order))
    (if first?
      (do
        (array/push new-kids k-node (ws " ") v-node)
        (set first? false))
      (array/push new-kids
                  (ws (string "\n" k-indent))
                  k-node (ws " ") v-node)))
  (z/replace cz [(first n) ;new-kids]))

(defn- ind-add-entries
  [cz els key-order]
  (def n (z/node cz))
  (def kids (slice n 1))
  (def col (content-col cz))
  (def e-indent (spaces (dec col)))
  (var first? (not (find non-trivia? kids)))
  (def new-kids (array ;kids))
  (each el els
    (def e-node (value->node el e-indent key-order))
    (if first?
      (do (array/push new-kids e-node) (set first? false))
      (array/push new-kids (ws (string "\n" e-indent)) e-node)))
  (z/replace cz [(first n) ;new-kids]))

(defn- drop-separator
  ```
  Removes the trivia separating the entry that was at `i` from its neighbours

  Prefers the preceding separator; falls back to the following one (so removing
  the first entry doesn't strand leading trivia).
  ```
  [kids start]
  (var i start)
  (if (and (> i 0) (trivia-node? (get kids (dec i))))
    (while (and (> i 0) (trivia-node? (get kids (dec i))))
      (array/remove kids (dec i))
      (-- i))
    (while (and (< i (length kids)) (trivia-node? (get kids i)))
      (array/remove kids i))))

(defn- dict-remove
  [cz k]
  (def n (z/node cz))
  (def kids (array ;(slice n 1)))
  (var ki nil)
  (for i 0 (length kids)
    (def kid (kids i))
    (when (and (non-trivia? kid) (= k (node->value kid)))
      (set ki i)
      (break)))
  (assertf ki "no key %n to remove" k)
  (var vi (inc ki))
  (while (and (< vi (length kids)) (trivia-node? (kids vi))) (++ vi))
  (array/remove kids ki (inc (- vi ki)))
  (drop-separator kids ki)
  (z/replace cz [(first n) ;kids]))

(defn- ind-remove
  [cz idx]
  (def n (z/node cz))
  (def kids (array ;(slice n 1)))
  (var ei nil)
  (var seen 0)
  (for i 0 (length kids)
    (when (non-trivia? (kids i))
      (if (= seen idx) (do (set ei i) (break)) (++ seen))))
  (assertf ei "no element %d to remove" idx)
  (array/remove kids ei)
  (drop-separator kids ei)
  (z/replace cz [(first n) ;kids]))

# Public API

(defn get
  ```
  Returns the Janet value at `path` in `tree`

  Returns `dflt` (or nil) if `path` is absent. A path present but holding the
  value nil is distinguished from an absent path only by `dflt`.
  ```
  [tree path &opt dflt]
  (if-let [vz (seek tree path)]
    (z/value vz)
    dflt))

(defn put
  ```
  Replaces the value at `path` in `tree` with `v`, returning the new tree

  Raises an error if `path` does not resolve to a value.
  ```
  [tree path v &named key-order]
  (def vz (seek tree path))
  (assertf vz "no value at path %n to replace" path)
  (def v-node (value->node v (spaces (dec (z/column-of vz))) key-order))
  (z/root (z/replace vz v-node)))

(defn update
  ```
  Replaces the value at `path` in `tree` with `(f current ;args)`
  ```
  [tree path f & args]
  (put tree path (f (get tree path) ;args)))

(defn add
  ```
  Adds the entries of `v` to the collection at `path` in `tree`

  For a struct or table, `v` must be a dictionary and its key-value pairs are
  added. For a tuple or array, `v` must be indexed and its elements are
  appended. Returns the new tree.
  ```
  [tree path v &named key-order]
  (def cz (seek tree path))
  (assertf cz "no collection at path %n" path)
  (def n (z/node cz))
  (z/root
    (cond
      (dict-node? n)
      (do
        (assertf (dictionary? v) "value for path %n must be a struct/table" path)
        (dict-add-entries cz (order-pairs v key-order) key-order))
      (ind-node? n)
      (do
        (assertf (indexed? v) "value for path %n must be a tuple/array" path)
        (ind-add-entries cz v key-order))
      (errorf "path %n resolves to %n, not a collection" path (node->value n)))))

(defn remove
  ```
  Removes the entry at `path` in `tree`, returning the new tree

  The last segment of `path` selects a key (in a struct/table) or an index (in
  a tuple/array). Surrounding separators are tidied up.
  ```
  [tree path]
  (assertf (not (empty? path)) "cannot remove at the empty path")
  (def cz (seek tree (slice path 0 -2)))
  (assertf cz "no collection at path %n" (slice path 0 -2))
  (def seg (last path))
  (def n (z/node cz))
  (z/root
    (cond
      (dict-node? n) (dict-remove cz seg)
      (ind-node? n) (ind-remove cz seg)
      (errorf "path %n resolves to %n, not a collection" path (node->value n)))))
