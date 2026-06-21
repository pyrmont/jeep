### Lossless reader/writer for Janet source
###
### `parse` turns a string of Janet source into a tree that preserves every
### byte (including whitespace and comments); `render` turns such a tree back
### into source. The two are inverses: (render (parse src)) reproduces src.
###
### A node is a tuple of the form [type & rest]:
###
###   - type - a keyword naming the node (e.g. :symbol, :tuple, :whitespace)
###   - rest - the literal text for atoms, or the child nodes for collections
###
### The root is an array node of the form @[:code & children].
###
### Nodes carry no source positions: a position is a property of the whole tree,
### not a node, and goes stale the moment the tree is edited. Use the zipper's
### `column-of` to compute a position on demand when one is needed.

# Node builders

(defn- atom-node
  ```
  Builds a grammar fragment that captures `peg-form` as an atom node of type
  `node-type` carrying its literal text.
  ```
  [node-type peg-form]
  ~(/ (capture ,peg-form)
      ,|[node-type $]))

(defn- reader-macro-node
  ```
  Builds a grammar fragment for a reader macro node of type `node-type`
  introduced by `sigil` (e.g. "~" for quasiquote).
  ```
  [node-type sigil]
  ~(/ (sequence ,sigil
                (group (sequence (any :non-form) :form)))
      ,|[node-type ;$]))

(defn- collection-node
  ```
  Builds a grammar fragment for a collection node of type `node-type` delimited
  by `open-delim` and `close-delim`. Raises a parse error if the closing
  delimiter is missing.
  ```
  [node-type open-delim close-delim]
  ~(/
     (sequence
       ,open-delim
       (group (any :input))
       (choice ,close-delim
               (error
                 (replace (sequence (line) (column))
                          ,|(string/format
                              "line: %p column: %p missing %p for %p"
                              $0 $1 close-delim node-type)))))
     ,|[node-type ;$]))

# Grammar

(def- grammar
  ~@{:main (some :input)
     #
     :input (choice :non-form :form)
     #
     :non-form (choice :whitespace :comment)
     #
     :whitespace ,(atom-node :whitespace
                             '(choice (some (set " \0\f\t\v"))
                                      (choice "\r\n" "\r" "\n")))
     #
     :comment ,(atom-node :comment
                          '(sequence "#" (any (if-not (set "\r\n") 1))))
     #
     :form (choice # reader macros
                   :fn :quasiquote :quote :splice :unquote
                   # collections
                   :array :bracket-array :tuple :bracket-tuple :table :struct
                   # atoms
                   :number :constant :buffer :string :long-buffer :long-string
                   :keyword :symbol)
     #
     :fn ,(reader-macro-node :fn "|")
     :quasiquote ,(reader-macro-node :quasiquote "~")
     :quote ,(reader-macro-node :quote "'")
     :splice ,(reader-macro-node :splice ";")
     :unquote ,(reader-macro-node :unquote ",")
     #
     :array ,(collection-node :array "@(" ")")
     :tuple ,(collection-node :tuple "(" ")")
     :bracket-array ,(collection-node :bracket-array "@[" "]")
     :bracket-tuple ,(collection-node :bracket-tuple "[" "]")
     :table ,(collection-node :table "@{" "}")
     :struct ,(collection-node :struct "{" "}")
     #
     :number ,(atom-node :number
                         ~(drop (sequence (cmt (capture (some :num-char))
                                               ,scan-number)
                                          (opt (sequence ":" (range "AZ" "az"))))))
     #
     :num-char (choice (range "09" "AZ" "az") (set "&+-._"))
     #
     :constant ,(atom-node :constant
                           '(sequence (choice "false" "nil" "true")
                                      (not :name-char)))
     #
     :name-char (choice (range "09" "AZ" "az" "\x80\xFF")
                        (set "!$%&*+-./:<?=>@^_"))
     #
     :buffer ,(atom-node :buffer
                         '(sequence `@"`
                                    (any (choice :escape (if-not "\"" 1)))
                                    `"`))
     #
     :escape (sequence "\\"
                       (choice (set `"'0?\abefnrtvz`)
                               (sequence "x" (2 :h))
                               (sequence "u" (4 :h))
                               (sequence "U" (6 :h))
                               (error (constant "bad escape"))))
     #
     :string ,(atom-node :string
                         '(sequence `"`
                                    (any (choice :escape (if-not "\"" 1)))
                                    `"`))
     #
     :long-string ,(atom-node :long-string :long-bytes)
     #
     :long-bytes {:main (drop (sequence :open
                                        (any (if-not :close 1))
                                        :close))
                  :open (capture :delim :n)
                  :delim (some "`")
                  :close (cmt (sequence (not (look -1 "`"))
                                        (backref :n)
                                        (capture (backmatch :n)))
                              ,=)}
     #
     :long-buffer ,(atom-node :long-buffer '(sequence "@" :long-bytes))
     #
     :keyword ,(atom-node :keyword '(sequence ":" (any :name-char)))
     #
     :symbol ,(atom-node :symbol '(some :name-char))})

# Parsing

(defn parse
  ```
  Parses a string of Janet `src` into a lossless tree

  Returns the root node, an array of the form `@[:code & children]`. Whitespace
  and comments are preserved as nodes, so that `render` can reproduce `src`
  exactly. An optional `start` index (default 0) sets the byte offset at which
  to begin parsing.

  Raises an error if `src` cannot be parsed.
  ```
  [src &opt start]
  (default start 0)
  (if-let [captures (peg/match grammar src start)]
    @[:code ;captures]
    @[:code]))

# Rendering

(defn- render*
  [node buf]
  (case (first node)
    :code (each child (drop 1 node) (render* child buf))
    :array (do (buffer/push-string buf "@(")
               (each child (drop 1 node) (render* child buf))
               (buffer/push-string buf ")"))
    :tuple (do (buffer/push-string buf "(")
               (each child (drop 1 node) (render* child buf))
               (buffer/push-string buf ")"))
    :bracket-array (do (buffer/push-string buf "@[")
                       (each child (drop 1 node) (render* child buf))
                       (buffer/push-string buf "]"))
    :bracket-tuple (do (buffer/push-string buf "[")
                       (each child (drop 1 node) (render* child buf))
                       (buffer/push-string buf "]"))
    :table (do (buffer/push-string buf "@{")
               (each child (drop 1 node) (render* child buf))
               (buffer/push-string buf "}"))
    :struct (do (buffer/push-string buf "{")
                (each child (drop 1 node) (render* child buf))
                (buffer/push-string buf "}"))
    :fn (do (buffer/push-string buf "|")
            (each child (drop 1 node) (render* child buf)))
    :quasiquote (do (buffer/push-string buf "~")
                    (each child (drop 1 node) (render* child buf)))
    :quote (do (buffer/push-string buf "'")
               (each child (drop 1 node) (render* child buf)))
    :splice (do (buffer/push-string buf ";")
                (each child (drop 1 node) (render* child buf)))
    :unquote (do (buffer/push-string buf ",")
                 (each child (drop 1 node) (render* child buf)))
    # atoms: emit literal text
    (buffer/push-string buf (in node 1))))

(defn render
  ```
  Renders Janet source from a `tree` produced by `parse`

  Returns a string. `(render (parse src))` reproduces `src` exactly.
  ```
  [tree]
  (def buf @"")
  (render* tree buf)
  (string buf))
