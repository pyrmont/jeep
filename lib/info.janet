### Bundle metadata editing
###
### A thin adapter over Honeycut that edits a bundle's `info.jdn` as data while
### preserving its formatting. Callers parse the file into an editable tree with
### `parse`, change it with `add` / `put` / `remove` / `update`, and render it
### back with `render`.
###
### The edit functions mutate the tree in place (and also return it), so callers
### can keep editing the same value across several calls.

(import ../deps/honeycut :as h)

(def- not-found (gensym))

(defn- by-name
  ```
  Orders a dictionary's pairs with `:name` first, then the rest by key
  ```
  [dict]
  (sort-by (fn [[k]] [(not= k :name) k]) (pairs dict)))

(defn- apply!
  ```
  Mutates `tree` in place to hold the contents of `new-tree`, returning `tree`
  ```
  [tree new-tree]
  (array/clear tree)
  (array/concat tree new-tree)
  tree)

(defn- resolves?
  ```
  Returns true if `path` resolves to a value in `tree`
  ```
  [tree path]
  (not= not-found (h/get tree path not-found)))

# Public API

(defn parse
  ```
  Parses a string of `info.jdn` source into an editable tree
  ```
  [s]
  (h/parse s))

(defn render
  ```
  Renders an editable tree back into a string of `info.jdn` source
  ```
  [tree]
  (h/render tree))

(defn add
  ```
  Adds the entries of `v` to the collection at key path `kl` in `tree`,
  mutating and returning `tree`

  If `kl` already resolves, `v`'s entries are added to the collection there (its
  elements for an array, its pairs for a struct/table). Otherwise the final key
  of `kl` is created in its parent and mapped to `v`.

  Unlike Honeycut's `add`, adding a key already present in the struct/table at
  `kl` raises an error rather than creating a duplicate entry; use `put` to
  replace an existing value.
  ```
  [tree kl v]
  (apply! tree
          (if (resolves? tree kl)
            (do
              (def coll (h/get tree kl))
              (when (dictionary? coll)
                (each k (keys v)
                  (assertf (not (has-key? coll k))
                           "key %n already present at key path %n; use put to replace"
                           k kl)))
              (h/add tree kl v :key-order by-name))
            (h/add tree (slice kl 0 -2) {(last kl) v} :key-order by-name))))

(defn put
  ```
  Sets key path `kl` in `tree` to `v`, mutating and returning `tree`

  If `kl` already resolves, its value is replaced. Otherwise the final key of
  `kl` is created in its parent and mapped to `v`.
  ```
  [tree kl v]
  (apply! tree
          (if (resolves? tree kl)
            (h/put tree kl v :key-order by-name)
            (h/add tree (slice kl 0 -2) {(last kl) v} :key-order by-name))))

(defn remove
  ```
  Removes the entry at key path `kl` in `tree`, mutating and returning `tree`

  Without `:where`, removes the key (or index) named by the last segment of
  `kl`. With `:where`, `kl` must resolve to an array and every element for which
  `where` (a value or a predicate function) matches is removed.
  ```
  [tree kl &named where]
  (apply! tree
          (if (nil? where)
            (h/remove tree kl)
            (let [coll (h/get tree kl not-found)
                  pred (if (function? where) where (partial deep= where))]
              (assertf (not= coll not-found)
                       "no match for key path '%n' in metadata" kl)
              (assertf (indexed? coll) ":where not implemented for structs/tables")
              (var t tree)
              (var i (dec (length coll)))
              (while (>= i 0)
                (when (pred (in coll i))
                  (set t (h/remove t [;kl i])))
                (-- i))
              t))))

(defn update
  ```
  Updates the elements matched by `where` at key path `kl` in `tree`, mutating
  and returning `tree`

  `kl` must resolve to an array and the update is applied to every element for
  which `where` (a value or a predicate function) matches. Exactly one of `:to`
  (a replacement value) or `:add` (key-value pairs to merge into a struct/table)
  must be given.

  To replace a value by its key path (rather than matched array elements), use
  `put`.
  ```
  [tree kl &named where add to]
  (assert (not (nil? where)) "must provide :where argument")
  (assert (not (and (nil? add) (nil? to))) "must provide :add or :to argument")
  (assert (or (nil? add) (nil? to)) "cannot provide both :add and :to arguments")
  (apply! tree
          (let [coll (h/get tree kl not-found)
                pred (if (function? where) where (partial deep= where))]
            (assertf (not= coll not-found)
                     "no match for key path '%n' in metadata" kl)
            (assertf (indexed? coll)
                     ":where argument requires array/tuple, found %n" coll)
            (var t tree)
            (for i 0 (length coll)
              (when (pred (in coll i))
                (def el (in coll i))
                (def v (if (nil? to)
                         (do
                           (assertf (dictionary? el)
                                    "expected struct/table, found %n" el)
                           (def merged (merge (struct/to-table el) (table ;add)))
                           (if (table? el) merged (table/to-struct merged)))
                         to))
                (set t (h/put t [;kl i] v :key-order by-name))))
            t)))
