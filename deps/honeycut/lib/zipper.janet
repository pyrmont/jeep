### A functional zipper over Honeycut trees
###
### A zipper location ("zloc") is a tuple [node state] that records a node
### together with enough context to walk and edit the surrounding tree without
### mutating it. Every move and edit returns a new zloc; `root` reassembles the
### whole tree, applying any edits made along the way.
###
### `state` is an immutable struct with the keys:
###
###   - :lhs       - left siblings (a tuple, nearest last)
###   - :rhs       - right siblings (a tuple, nearest first)
###   - :pnodes   - the path of ancestor nodes from the root
###   - :pstate   - the parent zloc's state
###   - :changed? - whether an edit has occurred at or below this location
###
### The root zloc's state is the empty struct.

(import ./parser)

# Node kinds that can hold children

(def- containers
  {:code true
   :tuple true :array true
   :bracket-tuple true :bracket-array true
   :struct true :table true
   :fn true :quote true :quasiquote true :unquote true :splice true})

(def- open-delims
  {:code "" :tuple "(" :array "@("
   :bracket-tuple "[" :bracket-array "@["
   :struct "{" :table "@{"
   :fn "|" :quote "'" :quasiquote "~" :unquote "," :splice ";"})

(defn- new-state
  [&opt ls rs pnodes pstate changed?]
  {:lhs ls :rhs rs :pnodes pnodes :pstate pstate :changed? changed?})

(defn- branch-node?
  [node]
  (and (indexed? node)
       (not (empty? node))
       (truthy? (get containers (first node)))))

(defn- node-children
  [node]
  (slice node 1))

(defn- with-children
  [node children]
  [(first node) ;children])

# Construction and access

(defn zip
  ```
  Returns a zipper location for the root of `tree`
  ```
  [tree]
  [tree {}])

(defn node
  ```
  Returns the node at `zloc`
  ```
  [zloc]
  (in zloc 0))

(defn state
  ```
  Returns the state struct for `zloc`
  ```
  [zloc]
  (in zloc 1))

(defn branch?
  ```
  Returns true if the node at `zloc` can hold children
  ```
  [zloc]
  (branch-node? (node zloc)))

(defn children
  ```
  Returns the child nodes of the branch at `zloc`

  Raises an error if `zloc` is not a branch.
  ```
  [zloc]
  (if (branch? zloc)
    (node-children (node zloc))
    (error "called `children` on a non-branch zloc")))

(defn root?
  ```
  Returns true if `zloc` is the root location
  ```
  [zloc]
  (empty? (state zloc)))

# Navigation

(defn down
  ```
  Moves to the leftmost child of `zloc`, or returns nil if there are none
  ```
  [zloc]
  (when (branch? zloc)
    (def kids (children zloc))
    (when (not (empty? kids))
      (def st (state zloc))
      [(first kids)
       (new-state []
                  (tuple/slice kids 1)
                  (if (root? zloc)
                    [(node zloc)]
                    [;(get st :pnodes) (node zloc)])
                  st
                  (get st :changed?))])))

(defn right
  ```
  Moves to the right sibling of `zloc`, or returns nil if there is none
  ```
  [zloc]
  (def st (state zloc))
  (def rs (get st :rhs))
  (when (and (not (root? zloc)) rs (not (empty? rs)))
    [(first rs)
     (new-state [;(get st :lhs) (node zloc)]
                (tuple/slice rs 1)
                (get st :pnodes)
                (get st :pstate)
                (get st :changed?))]))

(defn left
  ```
  Moves to the left sibling of `zloc`, or returns nil if there is none
  ```
  [zloc]
  (def st (state zloc))
  (def ls (get st :lhs))
  (when (and (not (root? zloc)) ls (not (empty? ls)))
    [(last ls)
     (new-state (tuple/slice ls 0 -2)
                [(node zloc) ;(get st :rhs)]
                (get st :pnodes)
                (get st :pstate)
                (get st :changed?))]))

(defn up
  ```
  Moves to the parent of `zloc`, or returns nil if `zloc` is the root
  ```
  [zloc]
  (def st (state zloc))
  (def pnodes (get st :pnodes))
  (when pnodes
    (def pnode (last pnodes))
    (if (get st :changed?)
      [(with-children pnode [;(get st :lhs) (node zloc) ;(get st :rhs)])
       (let [ps (get st :pstate)]
         (new-state (get ps :lhs) (get ps :rhs)
                    (get ps :pnodes) (get ps :pstate)
                    true))]
      [pnode (get st :pstate)])))

(defn rightmost
  ```
  Moves to the rightmost sibling of `zloc` (or stays put if already there)
  ```
  [zloc]
  (def st (state zloc))
  (def rs (get st :rhs))
  (if (and (not (root? zloc)) rs (not (empty? rs)))
    [(last rs)
     (new-state [;(get st :lhs) (node zloc) ;(tuple/slice rs 0 -2)]
                []
                (get st :pnodes)
                (get st :pstate)
                (get st :changed?))]
    zloc))

(defn leftmost
  ```
  Moves to the leftmost sibling of `zloc` (or stays put if already there)
  ```
  [zloc]
  (def st (state zloc))
  (def ls (get st :lhs))
  (if (and (not (root? zloc)) ls (not (empty? ls)))
    [(first ls)
     (new-state []
                [;(tuple/slice ls 1) (node zloc) ;(get st :rhs)]
                (get st :pnodes)
                (get st :pstate)
                (get st :changed?))]
    zloc))

(defn root
  ```
  Moves all the way up and returns the (possibly edited) root node
  ```
  [zloc]
  (if-let [parent (up zloc)]
    (root parent)
    (node zloc)))

# Editing

(defn replace
  ```
  Replaces the node at `zloc` with `a-node`, without moving
  ```
  [zloc a-node]
  (def st (state zloc))
  [a-node
   (new-state (get st :lhs) (get st :rhs)
              (get st :pnodes) (get st :pstate)
              true)])

(defn edit
  ```
  Replaces the node at `zloc` with `(f node ;args)`
  ```
  [zloc f & args]
  (replace zloc (f (node zloc) ;args)))

(defn insert-right
  ```
  Inserts `a-node` as the right sibling of `zloc`, without moving

  Raises an error if `zloc` is the root.
  ```
  [zloc a-node]
  (def st (state zloc))
  (if (root? zloc)
    (error "called `insert-right` at root")
    [(node zloc)
     (new-state (get st :lhs)
                [a-node ;(get st :rhs)]
                (get st :pnodes) (get st :pstate)
                true)]))

(defn insert-left
  ```
  Inserts `a-node` as the left sibling of `zloc`, without moving

  Raises an error if `zloc` is the root.
  ```
  [zloc a-node]
  (def st (state zloc))
  (if (root? zloc)
    (error "called `insert-left` at root")
    [(node zloc)
     (new-state [;(get st :lhs) a-node]
                (get st :rhs)
                (get st :pnodes) (get st :pstate)
                true)]))

(defn insert-child
  ```
  Inserts `a-node` as the leftmost child of `zloc`, without moving
  ```
  [zloc a-node]
  (replace zloc (with-children (node zloc) [a-node ;(children zloc)])))

(defn append-child
  ```
  Inserts `a-node` as the rightmost child of `zloc`, without moving
  ```
  [zloc a-node]
  (replace zloc (with-children (node zloc) [;(children zloc) a-node])))

(defn remove
  ```
  Removes the node at `zloc`

  Returns the location that precedes it in a depth-first walk. Raises an error
  if `zloc` is the root.
  ```
  [zloc]
  (def st (state zloc))
  (when (root? zloc)
    (error "called `remove` at root"))
  (def ls (get st :lhs))
  (if (not (empty? ls))
    # step to the (deep) rightmost of the previous sibling
    (do
      (var prev [(last ls)
                 (new-state (tuple/slice ls 0 -2)
                            (get st :rhs)
                            (get st :pnodes) (get st :pstate)
                            true)])
      (while (and (branch? prev) (down prev))
        (set prev (rightmost (down prev))))
      prev)
    # no left siblings: collapse into the parent
    (let [ps (get st :pstate)]
      [(with-children (last (get st :pnodes)) (get st :rhs))
       (new-state (get ps :lhs) (get ps :rhs)
                  (get ps :pnodes) (get ps :pstate)
                  true)])))

# Depth-first traversal

(defn df-next
  ```
  Moves to the next location in a depth-first walk

  Returns nil once the walk is exhausted.
  ```
  [zloc]
  (defn recur [z]
    (if-let [parent (up z)]
      (or (right parent) (recur parent))
      nil))
  (or (and (branch? zloc) (down zloc))
      (right zloc)
      (recur zloc)))

# Trivia-aware helpers
#
# Whitespace and comment nodes are "trivia": they carry formatting but no data.

(defn trivia?
  ```
  Returns true if the node at `zloc` is whitespace or a comment
  ```
  [zloc]
  (case (first (node zloc))
    :whitespace true
    :comment true
    false))

(defn right-skip
  ```
  Moves right from `zloc` past any trivia to the next sibling node

  Returns nil if there is no such sibling.
  ```
  [zloc]
  (var z (right zloc))
  (while (and z (trivia? z))
    (set z (right z)))
  z)

(defn left-skip
  ```
  Moves left from `zloc` past any trivia to the previous sibling node

  Returns nil if there is no such sibling.
  ```
  [zloc]
  (var z (left zloc))
  (while (and z (trivia? z))
    (set z (left z)))
  z)

(defn down-skip
  ```
  Moves to the first non-trivia child of `zloc`

  Returns nil if there are no such children.
  ```
  [zloc]
  (when-let [z (down zloc)]
    (if (trivia? z) (right-skip z) z)))

# Values

(defn value
  ```
  Returns the Janet value represented by the node at `zloc`

  The node is rendered back to source and parsed, so a `:keyword` node yields a
  keyword, a `:struct` node yields a struct, and so on.
  ```
  [zloc]
  (parse (parser/render (node zloc))))

(defn column-of
  ```
  Returns the 1-based column at which the node at `zloc` begins

  The column is measured from the rendered text to the node's left, so it is
  correct even for nodes inserted by edits (which carry no source location).
  ```
  [zloc]
  (defn prefix [z]
    (def left-text (string/join (map (fn [x] (parser/render x)) (get (state z) :lhs []))))
    (if-let [nl (last (string/find-all "\n" left-text))]
      (string/slice left-text (inc nl))
      (if-let [p (up z)]
        (string (prefix p) (get open-delims (first (node p)) "") left-text)
        left-text)))
  (inc (length (prefix zloc))))
