# Private values

(var- temp-counter 0)
(def- nl "\n")

# Public values

(def sep (get {:windows "\\" :cygwin "\\" :mingw "\\"} (os/which) "/"))

# Private helpers

(defn- cpr [src dest]
  (case (os/lstat src :mode)
    :directory
    (do
      (os/mkdir dest)
      (each p (os/dir src)
        (cpr (string src sep p) (string dest sep p))))
    # do nothing if file does not exist
    nil
    nil
    # default
    (do
      (def size 4096)
      (def buf @"")
      (with [src-file (file/open src :rb)]
        (with [dest-file (file/open dest :wb)]
          (while (def bytes (file/read src-file size buf))
            (file/write dest-file bytes)
            (buffer/clear buf)))))))

(defn- mkdirp [path]
  (var res false)
  (def pwd (os/cwd))
  (each part (string/split "/" path)
    (set res (os/mkdir part))
    (os/cd part))
  (os/cd pwd)
  res)

(defn- rmrf [path]
  (case (os/lstat path :mode)
    :directory
    (do
      (each p (os/dir path)
        (rmrf (string path sep p)))
      (os/rmdir path))
    # do nothing if file does not exist
    nil
    nil
    # default
    (os/rm path)))

(var- format (fn :format [v &opt indent]))

(defn- format-dict [d indent]
  (default indent 0)
  (def mut? (table? d))
  (def inner-indent (+ (if mut? 2 1) indent))
  (def padding (string/repeat " " inner-indent))
  (def dop (if mut? "@{" "{"))
  (def dcl "}")
  (def b @"")
  (buffer/push b dop)
  (var first? true)
  (eachp [k v] d
    (if first?
      (do
        (set first? false)
        (buffer/push b (format k inner-indent)))
      (buffer/push b nl padding (format k inner-indent)))
    (if (or (indexed? k) (dictionary? k))
      (buffer/push b nl padding (format v inner-indent))
      (buffer/push b " " (format v (+ (length (describe k)) 1 inner-indent)))))
  (buffer/push b dcl)
  (string b))

(defn- format-list [l indent]
  (default indent 0)
  (def mut? (array? l))
  (def inner-indent (+ (if mut? 2 1) indent))
  (def padding (string/repeat " " inner-indent))
  (def dop (if mut? "@[" "["))
  (def dcl "]")
  (def b @"")
  (buffer/push b dop)
  (var first? true)
  (each el l
    (if first?
      (do
        (set first? false)
        (buffer/push b (format el inner-indent)))
      (buffer/push b nl padding (format el inner-indent))))
  (buffer/push b dcl)
  (string b))

(set format (fn :format [v &opt indent]
  (default indent 0)
  (cond
    (dictionary? v)
    (format-dict v indent)
    (indexed? v)
    (format-list v indent)
    # default
    (describe v))))

# Public helpers

(defn add-nl
  "Adds a new line to a string"
  [s &opt n]
  (default n 1)
  (string s (string/repeat "\n" n)))

(defn copy-bundle
  "Copies a bundle from src to a destination"
  [src dest]
  (cpr src dest))

(defn fix-seps
  "Normalise path separators in s to be platform-specific."
  [s]
  (if (= "\\" sep)
    (string/replace "/" "\\" s)
    s))

(defn info-file
  "Retrieves the info file in `d`"
  [d]
  (slurp (string d sep "info.jdn")))

(defn make-bundle
  "Creates a minimal valid bundle structure in the given directory"
  [dir &named name version description dependencies vendored script]
  (default script "")
  (assert (not (nil? name)) "must provide :name")
  (def info @{:name name
              :version version
              :description description
              :dependencies dependencies
              :vendored vendored})
  (def broot (string dir sep name))
  (mkdirp broot)
  (spit (string broot sep "info.jdn") (format info) :wb)
  (spit (string broot sep "bundle.janet") script :wb)
  (os/realpath broot))

(defn make-manifests
  "Creates manifests in the given directory for the names"
  [dir & metas]
  (def mroot (string dir sep "bundle"))
  (mkdirp mroot)
  (each meta metas
    (def mpath (string mroot sep (meta :name)))
    (mkdirp mpath)
    (def manifest (string/format "%j" meta))
    (spit (string mpath sep "manifest.jdn") manifest :wb)))

(defn make-syspath
  "Creates a new syspath"
  [d]
  (mkdirp (string "_system" sep "bundle"))
  (def syspath (os/realpath "_system"))
  (setdyn :syspath syspath))

(defmacro in-dir
  ```
  Evaluates `body` in a temporary directory

  The path to the temporary directory is assigned to `binding`.
  ```
  [binding & body]
  (def p (string "tmp-" (gensym)))
  (def cwd (os/cwd))
  ~(do
     (,mkdirp ,p)
     (def ,binding (,os/realpath ,p))
     ,(apply defer ['do [os/cd cwd] [rmrf p]] [[os/cd p] ;body])))
