### Bundle metadata editing
###
### A thin adapter over Honeycut that edits a bundle's `info.jdn` as data while
### preserving its formatting. Callers parse the file into an editable tree with
### `parse`, change it with `append` / `put` / `remove` / `sort`, and
### render it back with `render`.

(import ../deps/honeycut :as h)

(def- not-found (gensym))

(defn- by-name
  ```
  Orders a dictionary's pairs with `:name` first, then the rest by key
  ```
  [dict]
  (sort-by (fn [[k]] [(not= k :name) k]) (pairs dict)))

(defn- resolves?
  ```
  Returns true if `path` resolves to a value in `tree`
  ```
  [tree path]
  (not= not-found (h/get tree path not-found)))

# Public API

(defn parse :shadow
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

(defn value
  ```
  Returns the Janet value represented by `tree`
  ```
  [tree]
  (h/get tree []))

(defn append
  ```
  Appends the elements of `v` to the indexed collection at key path `kl`

  If `kl` does not resolve, its final key is created and mapped to `v`.
  ```
  [tree kl v]
  (assertf (indexed? v) "value to append must be an array/tuple, got %n" v)
  (if (resolves? tree kl)
    (h/add tree kl v :key-order by-name)
    (h/add tree (slice kl 0 -2) {(last kl) v} :key-order by-name)))

(defn put :shadow
  ```
  Sets key path `kl` in `tree` to `v`, returning the edited tree

  If `kl` already resolves, its value is replaced. Otherwise the final key of
  `kl` is created in its parent and mapped to `v`.
  ```
  [tree kl v]
  (if (resolves? tree kl)
    (h/put tree kl v :key-order by-name)
    (h/add tree (slice kl 0 -2) {(last kl) v} :key-order by-name)))

(defn remove
  ```
  Removes the entry at key path `kl` in `tree`
  ```
  [tree kl]
  (h/remove tree kl))

(defn sort :shadow
  ```
  Sorts the entries of the collection at key path `kl`, returning the edited tree

  Entries are ordered by applying `by` (a function, default identity) to each
  entry's subject — its key for a struct/table, its element for an array/tuple
  — and sorting on the result. Comments and blank-line layout are preserved.

  Raises an error if `kl` does not resolve to a collection.
  ```
  [tree kl &named by]
  (h/sort tree kl :by by))
