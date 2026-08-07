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

(defn- node
  ```
  Returns a function that wraps its captures as a node of type `node-type`,
  i.e. a tuple of the form `[node-type & captures]`.
  ```
  [node-type]
  (fn [& captures] [node-type ;captures]))

(defn- missing-delim
  ```
  Returns a function that formats a parse error for a `node-type` collection
  whose closing `delim` is missing, given the line and column of the failure.
  ```
  [node-type delim]
  (fn [line col]
    (string/format "line: %p column: %p missing %p for %p"
                   line col delim node-type)))

# Grammar

(def- grammar
  (peg/compile
    ~{:main (some :input)
      :input (+ :non-form :form)
      # Whitespace and comments
      :non-form (+ :whitespace :comment)
      :whitespace (/ '(+ (some (set " \0\f\t\v"))
                         (+ "\r\n" "\r" "\n"))
                     ,(node :whitespace))
      :comment (/ '(* "#" (any (* (! (set "\r\n")) 1)))
                  ,(node :comment))
      # Forms
      :form (+ # reader macros
               :fn :quasiquote :quote :splice :unquote
               # collections
               :array :bracket-array :tuple :bracket-tuple :table :struct
               # atoms
               :number :constant :buffer :string :long-buffer :long-string
               :keyword :symbol)
      # Reader macros
      :fn         (/ (* "|" (any :non-form) :form) ,(node :fn))
      :quasiquote (/ (* "~" (any :non-form) :form) ,(node :quasiquote))
      :quote      (/ (* "'" (any :non-form) :form) ,(node :quote))
      :splice     (/ (* ";" (any :non-form) :form) ,(node :splice))
      :unquote    (/ (* "," (any :non-form) :form) ,(node :unquote))
      # Collections
      :array (/ (* "@(" (any :input)
                   (+ ")" (error (/ (* (line) (column))
                                    ,(missing-delim :array ")")))))
                ,(node :array))
      :tuple (/ (* "(" (any :input)
                   (+ ")" (error (/ (* (line) (column))
                                    ,(missing-delim :tuple ")")))))
                ,(node :tuple))
      :bracket-array (/ (* "@[" (any :input)
                           (+ "]" (error (/ (* (line) (column))
                                            ,(missing-delim :bracket-array "]")))))
                        ,(node :bracket-array))
      :bracket-tuple (/ (* "[" (any :input)
                           (+ "]" (error (/ (* (line) (column))
                                            ,(missing-delim :bracket-tuple "]")))))
                        ,(node :bracket-tuple))
      :table (/ (* "@{" (any :input)
                   (+ "}" (error (/ (* (line) (column))
                                    ,(missing-delim :table "}")))))
                ,(node :table))
      :struct (/ (* "{" (any :input)
                    (+ "}" (error (/ (* (line) (column))
                                     ,(missing-delim :struct "}")))))
                 ,(node :struct))
      # Numbers and constants
      :number (/ '(drop (* (cmt '(some :num-char) ,scan-number)
                           (? (* ":" (range "AZ" "az")))))
                 ,(node :number))
      :num-char (+ (range "09" "AZ" "az") (set "&+-._"))
      :constant (/ '(* (+ "false" "nil" "true") (! :name-char))
                   ,(node :constant))
      :name-char (+ (range "09" "AZ" "az" "\x80\xFF")
                    (set "!$%&*+-./:<?=>@^_"))
      # Strings and buffers
      :buffer (/ '(* `@"` (any (+ :escape (* (! `"`) 1))) `"`)
                 ,(node :buffer))
      :string (/ '(* `"` (any (+ :escape (* (! `"`) 1))) `"`)
                 ,(node :string))
      :escape (* "\\"
                 (+ (set `"'0?\abefnrtvz`)
                    (* "x" (2 :h))
                    (* "u" (4 :h))
                    (* "U" (6 :h))
                    (error (constant "bad escape"))))
      :long-string (/ ':long-bytes ,(node :long-string))
      :long-buffer (/ '(* "@" :long-bytes) ,(node :long-buffer))
      :long-bytes {:main (drop (* :open (any (* (! :close) 1)) :close))
                   :open (<- :delim :n)
                   :delim (some "`")
                   :close (cmt (* (! (> -1 "`"))
                                  (backref :n)
                                  (<- (backmatch :n)))
                               ,=)}
      # Keywords and symbols
      :keyword (/ '(* ":" (any :name-char)) ,(node :keyword))
      :symbol (/ '(some :name-char) ,(node :symbol))}))

# Parsing

(defn parse :shadow
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
  [tree buf]
  (case (first tree)
    :code (each child (drop 1 tree) (render* child buf))
    :array (do (buffer/push-string buf "@(")
               (each child (drop 1 tree) (render* child buf))
               (buffer/push-string buf ")"))
    :tuple (do (buffer/push-string buf "(")
               (each child (drop 1 tree) (render* child buf))
               (buffer/push-string buf ")"))
    :bracket-array (do (buffer/push-string buf "@[")
                       (each child (drop 1 tree) (render* child buf))
                       (buffer/push-string buf "]"))
    :bracket-tuple (do (buffer/push-string buf "[")
                       (each child (drop 1 tree) (render* child buf))
                       (buffer/push-string buf "]"))
    :table (do (buffer/push-string buf "@{")
               (each child (drop 1 tree) (render* child buf))
               (buffer/push-string buf "}"))
    :struct (do (buffer/push-string buf "{")
                (each child (drop 1 tree) (render* child buf))
                (buffer/push-string buf "}"))
    :fn (do (buffer/push-string buf "|")
            (each child (drop 1 tree) (render* child buf)))
    :quasiquote (do (buffer/push-string buf "~")
                    (each child (drop 1 tree) (render* child buf)))
    :quote (do (buffer/push-string buf "'")
               (each child (drop 1 tree) (render* child buf)))
    :splice (do (buffer/push-string buf ";")
                (each child (drop 1 tree) (render* child buf)))
    :unquote (do (buffer/push-string buf ",")
                 (each child (drop 1 tree) (render* child buf)))
    # atoms: emit literal text
    (buffer/push-string buf (in tree 1))))

(defn render
  ```
  Renders Janet source from a `tree` produced by `parse`

  Returns a string. `(render (parse src))` reproduces `src` exactly.
  ```
  [tree]
  (def buf @"")
  (render* tree buf)
  (string buf))
