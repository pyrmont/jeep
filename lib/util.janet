(defdyn *gitpath* "What git command to use to fetch dependencies")
(defdyn *tarpath* "What tar command to use to fetch dependencies")
(defdyn *curlpath* "What curl command to use to fetch dependencies")

(def colours {:green "\e[32m" :red "\e[31m"})

(def psep "/")
(def wsep "\\")
(def sep (get {:windows wsep :cygwin wsep :mingw wsep} (os/which) psep))
(def dir-suffix "/.")

(def windows? (= sep wsep))

(def pathg ~{:main    (* (+ :abspath :relpath) (? :sep) -1)
             :abspath (* :root (any :relpath))
             :relpath (* :part (any (* :sep :part)))
             :root    (+ (* ,sep (constant ""))
                         (* '(* :a ":") ,wsep))
             :sep     (some ,sep)
             :part    '(some (* (! :sep) 1))})

# used for splitting POSIX paths
(def- posix-pathg ~{:main     (* (+ :abspath :relpath) (? :sep) -1)
                    :abspath  (* :root (any :relpath))
                    :relpath  (* :part (any (* :sep :part)))
                    :root     (* ,psep (constant ""))
                    :sep      (some ,psep)
                    :part     '(some (* (! :sep) 1))})

# Path

(def- this-file (os/realpath (dyn :current-file)))

# Independent functions

(defn abspath?
  [path]
  (if (= :windows (os/which))
    (not (nil? (peg/match ~(* (? (* :a ":")) ,wsep) path)))
    (string/has-prefix? psep path)))

(defn apart
  [path &opt posix?]
  (if (empty? path)
    []
    (or (peg/match (if posix? posix-pathg pathg) path)
        (error "invalid path"))))

(defn colour
  [c text &opt force?]
  (default force? false)
  (if (or (os/isatty) force?)
    (string (get colours c "\e[0m") text "\e[0m")
    text))

(defn devnull
  []
  (os/open (if (= :windows (os/which)) "NUL" "/dev/null") :rw))

(defn exec
  [cmd stdio & args]
  (def {:out out :err err} (if (nil? stdio) {:out nil :err nil} stdio))
  (def dn (if (or (nil? out) (nil? err)) (devnull)))
  (default out dn)
  (default err dn)
  (def command [(dyn (keyword cmd "path") (string cmd)) ;args])
  (try
    (os/execute command :px {:out out :err err})
    ([e f]
     (propagate (string e "; command: " (string/join (map string command) " ")) f))))

(defn fexists?
  [p]
  (= :file (os/stat p :mode)))

(defn legacy-bundles
  []
  (var res @[])
  (def mpath (string (dyn :syspath) sep ".manifests"))
  (unless (= :directory (os/stat mpath :mode))
    (break res))
  (each entry (os/dir mpath)
    (when (string/has-suffix? ".jdn" entry)
      (array/push res (string/slice entry 0 -5))))
  res)

(defn rmrf
  [path &opt ignore-check?]
  (case (os/lstat path :mode)
    # recursive delete directories
    :directory
    (do
      (def msg "cannot delete directory while current working directory is inside it")
      (assert (or ignore-check? (not (string/has-prefix? path (os/cwd)))) msg)
      (each subpath (os/dir path)
        (rmrf (string path sep subpath) true))
      (os/rmdir path))
     # do nothing if file does not exist
    nil
    nil
    # default
    (os/rm path)))

(defn slurp-maybe
  [path]
  (when-with [f (file/open path)]
    (file/read f :all)))

(defn spit-maybe
  [path s]
  (when-with [f (file/open path :wb)]
    (file/write f s)))

(defn tmp-dir
  []
  (unless (nil? (dyn :jeep-tmpdir))
    (break (dyn :jeep-tmpdir)))
  (def rng (math/rng))
  (loop [:repeat 5]
    (def total 8)
    (def b (buffer/new total))
    (loop [:repeat total]
      (buffer/push b (+ 65 (math/rng-int rng 25))))
    (def d (string "tmp_" b))
    (when (os/mkdir d)
      (setdyn :jeep-tmpdir (os/realpath d))
      (break)))
  (assert (dyn :jeep-tmpdir) "cannot create temporary directory")
  (dyn :jeep-tmpdir))

(defn url?
  [s]
  (def res (peg/match
             ~{:main (* :prot :domain :path :qs -1)
               :prot (? (* :w+ "://"))
               :domain (* :-w+ (some (* "." :-w+)))
               :-w+ (some (+ "-" :w))
               :path (? (* "/" (any (+ :w (set "./-_")))))
               :qs (? (* "?" (any (+ :w (set "./-_=")))))}
             s))
  (not (nil? res)))

# Directory functions

(defn abspath
  [path]
  (if (abspath? path)
    path
    (string (os/cwd) sep path)))

(defn mkdir
  [path &opt posix?]
  (def parts (apart path posix?))
  (cond
    # absolute path
    (= "" (first parts))
    (put parts 0 (if posix? psep sep))
    # Windows path beginning with drive letter
    (string/has-suffix? ":" (first parts))
    (put parts 0 (string (first parts) wsep)))
  (var res false)
  (def cwd (os/cwd))
  (each part parts
    (set res (os/mkdir part))
    (os/cd part))
  (os/cd cwd)
  res)

(defn parent
  [path &opt level posix?]
  (default level 1)
  (def parts (apart path posix?))
  (when (empty? parts)
    (break parts))
  (def s (if posix? psep sep))
  (def joined (string/join (array/slice parts 0 (- -1 level)) s))
  (if (= "" joined)
    sep
    joined))

(defn win-path
  [s]
  (def trailing (if (string/has-suffix? psep s) sep ""))
  (-> (apart s true) (string/join sep) (string trailing)))

# Other functions

(defn change-syspath
  [path]
  (def ap (abspath path))
  (unless (= :directory (os/stat ap :mode))
    (mkdir ap))
  (setdyn *syspath* ap))

(defn cleanup
  [cwd]
  (os/cd cwd)
  (when (def d (dyn :jeep-tmpdir))
    (rmrf d)
    (setdyn :jeep-tmpdir nil)))

(defn copy
  [src dest]
  (if (= :windows (os/which))
    (do
      (def copy-contents? (string/has-suffix? "\\." src))
      (def xcopy-src (if copy-contents?
                       (string (string/slice src 0 -2) "*")
                       src))
      (def express? (string/has-suffix? sep dest))
      (def xcopy-dest
        (cond
          express?
          dest
          copy-contents?
          (string dest sep)
          # default
          (do
            (def dir (parent dest))
            (def res (string dir sep (gensym)))
            # this is not cleaned up if there's an error
            (os/mkdir res)
            (string res sep))))
      (os/shell (string "C:\\Windows\\System32\\xcopy.exe "
                        xcopy-src
                        " "
                        xcopy-dest
                        " /e /h /i /k /o /r /x /y >NUL"))
      # Only move if not express and not copying contents
      (unless (or express? copy-contents?)
        (os/shell (string "C:\\Windows\\System32\\cmd.exe /c move "
                          (string/slice xcopy-dest 0 -2)
                          " "
                          dest
                          " >NUL"))))
    (os/execute ["cp" "-a" src dest] :px)))

(defn fetch-url
  ```
  Fetches the contents of `url` using curl, returning the body or nil on failure
  ```
  [url]
  (def [r w] (os/pipe))
  # exec runs with the :x flag, so a non-zero exit (e.g. a 404) throws
  (def ok? (first (protect (exec :curl {:out w} "-sSL" "--fail" url))))
  (:close w)
  (def body (ev/read r :all))
  (:close r)
  (when ok? body))

(defn- resolve-fallbacks
  ```
  Resolves the `:jeep-fallbacks` dynamic binding into a fallbacks map

  The binding may be nil, a URL string, an indexed collection of URL strings or
  an already-resolved map. URL sources are tried in order; the first that
  fetches and parses into a struct/table is used. The result (or an empty map if
  nothing resolves) is cached back into the binding so the file is fetched at
  most once per run.
  ```
  []
  (def fb (dyn :jeep-fallbacks))
  (cond
    (nil? fb)
    nil
    (dictionary? fb)
    fb
    # default: one or more URLs to fetch
    (do
      (def sources (if (indexed? fb) fb [fb]))
      (var resolved nil)
      (each src sources
        (def body (fetch-url src))
        (when body
          (def [ok? data] (protect (parse body)))
          (when (and ok? (dictionary? data))
            (set resolved data)
            (break))))
      (unless resolved
        (eprint "warning: could not load fallbacks from "
                (string/join (map string sources) ", ")))
      (def result (or resolved {}))
      (setdyn :jeep-fallbacks result)
      result)))

(defn with-fallback
  ```
  Runs `(thunk url)`, retrying with fallback URLs if it throws

  If the call throws, `url` is looked up in the resolved fallbacks map (see the
  `:jeep-fallbacks` dynamic binding). Each alternative is tried in turn by
  calling `(thunk alt)` and the first that succeeds has its result returned. If
  there are no alternatives or all of them fail, the original error is re-raised.
  ```
  [url thunk]
  # try (rather than a bare fiber) so the thunk inherits dynamic bindings
  (try
    (thunk url)
    ([err fib]
     (def alts (get (resolve-fallbacks) url))
     (if (or (nil? alts) (empty? alts))
       (propagate err fib)
       (do
         (var result nil)
         (var ok? false)
         (each alt alts
           (eprint "warning: " url " did not resolve, trying " alt)
           (def [success v] (protect (thunk alt)))
           (when success
             (set result v)
             (set ok? true)
             (break)))
         (if ok? result (propagate err fib)))))))

(defn fetch-git
  [&named url tag dir]
  (assert url "function requires :url argument")
  (assert dir "function requires :dir argument")
  (default tag "HEAD")
  (def sha? (peg/match '(between 7 40 :h) tag))
  (if (= "HEAD" tag)
    (exec :git nil "clone" "--depth" "1" url dir)
    (if (not sha?)
      (exec :git nil "clone" "--branch" tag "--depth" "1" url dir)
      (do
        (exec :git nil "clone" "--filter" "blob:none" "--no-checkout" url dir)
        (exec :git nil "-C" dir "fetch" "origin" tag)
        (exec :git nil "-C" dir "checkout" tag))))
  dir)

(defn fetch-dep
  [dep &opt parent-dir]
  (def {:name name
        :url url
        :tag tag
        :prefix prefix
        :paths files} dep)
  (default files
    (do
      (print "warning: use of :files is deprecated in vendored dependencies")
      (get dep :files)))
  (assert url (error "fetched bundles need a :url key"))
  (def tmp (tmp-dir))
  (def cwd (os/cwd))
  (defer (do
           (os/cd cwd)
           (rmrf tmp))
    (def local? (string/has-prefix? "file::" url))
    (def origin (if local? (string/slice url 6) url))
    (print "vendoring " (if local? (win-path origin) origin))
    (try
      (do
        (def src-dir
          (if local?
            origin
            (with-fallback url
                           (fn [u]
                             # clone each attempt into a fresh dir so a failed try
                             # never leaves a half-clone behind for the next one
                             (def dir (string tmp psep (gensym)))
                             (fetch-git :url u :tag tag :dir dir)))))
        (def dest-dir (if parent-dir
                        # use POSIX path separator to match info file
                        (string parent-dir (when prefix (string psep prefix)))
                        (or prefix ".")))
        (mkdir dest-dir true)
        (def to-plat (if (= wsep sep) win-path identity))
        (each f files
          (def [src dest] (if (indexed? f) f [f f]))
          (def full-src (string src-dir psep src))
          # use POSIX path separators to match info file
          (def posix-to (string dest-dir psep dest))
          (if (string/has-suffix? psep posix-to)
            (mkdir posix-to true)
            (mkdir (parent posix-to 1 true) true))
          (def posix-from
            (if (and (not (string/has-suffix? dir-suffix full-src))
                     (= :directory (os/stat full-src :mode)))
              (string full-src dir-suffix)
              full-src))
          (def from (to-plat posix-from))
          (def to (to-plat posix-to))
          (print "  copying " from " to " to)
          (copy from to)))
      ([e f]
       (def ident (if name (string name " (" url ")") url))
       (propagate (string "failed to vendor " ident ": " e) f)))))

(defn find-info
  [&opt dir]
  (default dir ".")
  (def info-path1 (string/join [dir "bundle" "info.jdn"] sep))
  (def info-path2 (string/join [dir "info.jdn"] sep))
  (cond
    (fexists? info-path1) info-path1
    (fexists? info-path2) info-path2))

(defn load-info
  [&opt dir]
  (when-let [info-path (find-info dir)]
    (slurp-maybe info-path)))

(defn load-meta
  [&opt dir]
  (default dir ".")
  (when-let [info (load-info dir)]
    (parse info)))

(defn local-hook
  [name & args]
  (def [ok? module] (protect (require "/bundle" :fresh true)))
  (assert ok? "failed to load bundle script")
  (when-let [hookf (module/value module (symbol name))]
    (apply hookf args)
    true))

(defn save-info
  [jdn &opt dir]
  (default dir ".")
  # write back to the file `load-info` reads, creating the aliased info file
  # only if no info file exists yet
  (def info-path (or (find-info dir) (string/join [dir "info.jdn"] sep)))
  (assertf (spit-maybe info-path jdn) "cannot write to %s" info-path))

(defn version
  []
  (if (string/has-prefix? (os/realpath (dyn :syspath)) this-file)
    (get (bundle/manifest "jeep") :version)
    (do
      (def [r w] (os/pipe))
      (def bundle-root (-> this-file parent parent))
      (def ver "local")
      (os/cd bundle-root)
      (def [ok? _] (protect (exec :git {:out w} "describe" "--always" "--dirty")))
      (:close w)
      (if ok?
        (string ver "-" (string/trim (ev/read r :all)))
        ver))))
