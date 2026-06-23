### Data-level editing of Janet source
###
### These functions treat a parsed tree as the Janet *value* it represents and
### let you read and edit it by key path, the way `get-in` / `put-in` /
### `update-in` work on live data — except the surrounding source (whitespace,
### comments, the formatting of untouched entries) is preserved.
###
### A `path` is a tuple of keys. Within a struct or table a key looks up an
### entry; within a tuple or array it is a 0-based index. New and replacement
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
  Returns the value z-location for `k` within the collection at `coll-zloc`,
  or nil if it is absent
  ```
  [coll-zloc k]
  (def n (z/node coll-zloc))
  (cond
    (dict-node? n)
    (do
      (var kz (z/down-skip coll-zloc))
      (var found nil)
      (while kz
        (if (= k (z/value kz))
          (do (set found (z/right-skip kz)) (set kz nil))
          (set kz (z/right-skip (z/right-skip kz)))))
      found)
    (ind-node? n)
    (do
      (var ez (z/down-skip coll-zloc))
      (var i 0)
      (while (and ez (< i k))
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
  Returns the value z-location at `path`, or nil if any key is absent
  ```
  [tree path]
  (var cur (top tree))
  (each k path
    (if (nil? cur) (break))
    (set cur (seek-in cur k)))
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
  (def lead-text (string/join (map (fn [x] (in x 1)) lead)))
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

(defn- comment-line? [line]
  (def t (string/triml line))
  (and (not (empty? t)) (= (t 0) (chr "#"))))

(defn- peel-lead
  ```
  Splits trivia text `s` into `[structural lead]`, where `lead` is the trailing
  run of own-line comments (and the indent before the next entry)

  A blank line detaches a comment from what follows, ending the run. When
  `first-line?` is true the first line is eligible too, so a comment opening the
  collection attaches to its first entry; otherwise the first line is the close
  of the preceding entry's line and stays structural.
  ```
  [s first-line?]
  (def parts (string/split "\n" s))
  (def min-j (if first-line? 0 1))
  (var first-comment nil)
  (var j (- (length parts) 2))
  (while (and (>= j min-j) (comment-line? (parts j)))
    (set first-comment j)
    (-- j))
  (if (nil? first-comment)
    [s ""]
    (do
      (var off 0)
      (for k 0 first-comment (+= off (length (parts k)) 1))
      (def cut (+ off (string/find "#" (parts first-comment))))
      [(string/slice s 0 cut) (string/slice s cut)])))

(defn- peel-tail
  ```
  Splits gap text `s` into `[tail rest]`, where `tail` is a same-line trailing
  comment of the preceding entry (empty if the gap opens with a newline)
  ```
  [s]
  (def nl (string/find "\n" s))
  (if (and nl (string/find "#" (string/slice s 0 nl)))
    [(string/slice s 0 nl) (string/slice s nl)]
    ["" s]))

(defn- parse-collection
  ```
  Splits collection children `kids` into a head, entries and separators

  Each entry spans `width` non-trivia nodes (1 for an element, 2 for a
  key/value pair). Returns `[head entries seps]` where `head` is the leading
  structural trivia and each `seps` entry is the structural separator following
  a slot, both as text; each entry is a struct of `:lead` (own-line comments
  above it) and `:tail` (a same-line trailing comment), both text, plus
  `:content` (its own nodes). Comments bind to the entry they document; only
  the structural separators are positional.
  ```
  [kids width]
  (var i 0)
  (def head-trivia @[])
  (while (and (< i (length kids)) (trivia-node? (kids i)))
    (array/push head-trivia (kids i))
    (++ i))
  (def raw @[])
  (while (< i (length kids))
    (def content @[])
    (var seen 0)
    (while (and (< i (length kids)) (< seen width))
      (def kid (kids i))
      (array/push content kid)
      (when (non-trivia? kid) (++ seen))
      (++ i))
    (def gap @"")
    (while (and (< i (length kids)) (trivia-node? (kids i)))
      (buffer/push gap (in (kids i) 1))
      (++ i))
    (array/push raw {:content content :gap (string gap)}))
  (def m (length raw))
  (def [head lead0]
    (peel-lead (string/join (map |(in $ 1) head-trivia)) true))
  (def tails @[])
  (def seps @[])
  (def next-leads @[])
  (for idx 0 m
    (def [tail rest] (peel-tail ((raw idx) :gap)))
    (def [sep next-lead] (if (= idx (dec m)) [rest ""] (peel-lead rest false)))
    (array/push tails tail)
    (array/push seps sep)
    (array/push next-leads next-lead))
  (def entries @[])
  (for idx 0 m
    (array/push entries
                {:lead (if (zero? idx) lead0 (next-leads (dec idx)))
                 :content ((raw idx) :content)
                 :tail (tails idx)}))
  [head entries seps])

(defn- reorder
  ```
  Rebuilds a collection's children from `head`, the original `entries`, an
  `order` of entry indices, and the positional `seps`

  Each entry carries its own leading and trailing comments to its new slot,
  while the structural separators stay where they were, so blank lines and
  layout are preserved and comments travel with the entry they document.
  ```
  [kind head entries order seps]
  (def buf (buffer head))
  (for s 0 (length entries)
    (def e (entries (order s)))
    (buffer/push buf (e :lead))
    (each node (e :content) (buffer/push buf (parser/render node)))
    (buffer/push buf (e :tail))
    (buffer/push buf (seps s)))
  # a comment flush against the opening delimiter would swallow it onto its
  # line, so give it a space to breathe
  (def body (if (= (get buf 0) (chr "#")) (string " " buf) (string buf)))
  [kind ;(slice (parser/parse body) 1)])

(defn- sort-collection
  ```
  Reorders the entries of the collection at `cz` by `by`, applied to each
  entry's subject

  An entry spans `width` non-trivia nodes; its subject is the first of them — a
  key for a struct or table, an element for a tuple or array. The original
  position breaks ties, keeping the sort stable.
  ```
  [cz width by]
  (def n (z/node cz))
  (def [head entries seps] (parse-collection (slice n 1) width))
  (if (<= (length entries) 1)
    cz
    (do
      (def subjects
        (map (fn [e] (node->value (first (filter non-trivia? (e :content))))) entries))
      (def order
        (sort-by (fn [i] [(by (subjects i)) i]) (range (length entries))))
      (z/replace cz (reorder (first n) head entries order seps)))))

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

  As in `add`, the optional `:key-order` hook sets the order in which
  dictionary keys are emitted as `v` is rendered: it maps `v`, and every
  dictionary nested within it, to its ordered `[key value]` pairs (the default
  sorts them). It governs only this freshly rendered text; entries already in
  `tree` keep their order. Use `sort` to reorder a collection already in the
  tree.

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
  Adds the entries of `v` to the collection at `path` in `tree`, returning the
  new tree

  If `path` resolves to a struct or table, `v` must also be a dictionary and
  its key-value pairs are added. If `path` resolves to an array or tuple, `v`
  must be an indexed collection and its elements are appended.

  As in `put`, the optional `:key-order` hook sets the order in which
  dictionary keys are emitted as `v` is rendered: it maps `v`, and every
  dictionary nested within it, to its ordered `[key value]` pairs (the default
  sorts them). It governs only this freshly rendered text. The added entries
  follow those already at `path`, which keep their order; use `sort` to
  reorder a collection already in the tree.

  A key in `v` that is already present in the dictionary at `path` is added a
  second time rather than overwriting the existing entry; use `put` to replace
  a value in place.

  Raises an error if `path` does not resolve to a collection or if `v` is not
  of a matching type.
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

(defn sort
  ```
  Reorders the entries of the collection at `path` in `tree`, returning the
  new tree

  Entries are ordered by applying the optional `:by` hook and sorting on the
  result. For a struct or table `:by` receives each entry's key; for a tuple or
  array it receives each element. The default is the identity, so dictionaries
  sort by key and indexed collections sort by element.

  This rearranges entries already in the tree and touches only the collection
  at `path`; nested collections are left as they are. By contrast, the
  `:key-order` hook of `add` and `put` sets the order of dictionaries — nested
  ones included — only as fresh values are rendered.

  A comment travels with the entry it documents: an own-line comment moves with
  the entry it sits above, and a same-line trailing comment moves with the entry
  it follows. A comment cut off from the next entry by a blank line is treated
  as free-standing and keeps its position, as does the blank-line layout itself.

  Raises an error if `path` does not resolve to a collection.
  ```
  [tree path &named by]
  (def by (or by identity))
  (def cz (seek tree path))
  (assertf cz "no collection at path %n" path)
  (def n (z/node cz))
  (z/root
    (cond
      (dict-node? n) (sort-collection cz 2 by)
      (ind-node? n) (sort-collection cz 1 by)
      (errorf "path %n resolves to %n, not a collection" path (node->value n)))))

(defn remove
  ```
  Removes the entry at `path` in `tree`, returning the new tree

  The last key of `path` identifies the entry: a key in a struct/table or an
  index in a tuple/array. Surrounding separators are tidied up.

  Raises an error if `path` is empty or does not resolve to an entry.
  ```
  [tree path]
  (assertf (not (empty? path)) "cannot remove at the empty path")
  (def cz (seek tree (slice path 0 -2)))
  (assertf cz "no collection at path %n" (slice path 0 -2))
  (def k (last path))
  (def n (z/node cz))
  (z/root
    (cond
      (dict-node? n) (dict-remove cz k)
      (ind-node? n) (ind-remove cz k)
      (errorf "path %n resolves to %n, not a collection" path (node->value n)))))
