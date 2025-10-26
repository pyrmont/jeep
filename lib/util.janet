(defdyn *gitpath* "What git command to use to fetch dependencies")
(defdyn *tarpath* "What tar command to use to fetch dependencies")
(defdyn *curlpath* "What curl command to use to fetch dependencies")

(def colours {:green "\e[32m" :red "\e[31m"})

(def sep (get {:windows "\\" :cygwin "\\" :mingw "\\"} (os/which) "/"))
(def esc (cond (os/getenv "PSModulePath")
               "`"
               (index-of (os/which) [:mingw :windows])
               "^"
               # default
               "\\"))

(def pathg ~{:main (* (+ :abspath :relpath) (? :sep) -1)
             :abspath (* :root (any :relpath))
             :relpath (* :part (any (* :sep :part)))
             :root '(+ "/" (* (? (* :a ":")) `\`))
             :sep ,sep
             :part (* (+ :quoted :unquoted) (> (+ :sep -1)))
             :quoted (* `"`
                        (% (some (+ (* ,esc ,esc)
                                 (* ,esc `"`)
                                 (* (! `"`) '1))))
                        `"`)
             :unquoted (% (some (+ :escaped (* (! (set `"\/ `)) '1))))
             :escaped (* ,esc '1)})

# Path

(def- this-file (dyn :current-file))

# Independent functions

(defn abspath?
  [path]
  (if (= :windows (os/which))
    (peg/match '(* (? (* :a ":")) `\`) path)
    (string/has-prefix? "/" path)))

(defn apart
  [path]
  (if (empty? path)
    []
    (or (peg/match pathg path)
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
  (def {:out out :err err} stdio)
  (def dn (if (or (nil? out) (nil? err)) (devnull)))
  (default out dn)
  (default err dn)
  (os/execute [(dyn (keyword cmd "path") (string cmd)) ;args] :px {:out out :err err}))

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
  [path]
  (case (os/lstat path :mode)
    :directory (do
                 (each subpath (os/dir path)
                   (rmrf (string path sep subpath)))
                 (os/rmdir path))
    nil nil # do nothing if file does not exist
    (os/rm path)))

(defn slurp-maybe
  [path]
  (when-with [f (file/open path)]
    (file/read f :all)))

(defn spit-maybe
  [path s]
  (when-with [f (file/open path :w)]
    (file/write f s)))

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

# Dependent functions

(defn abspath
  [path]
  (if (abspath? path)
    path
    (string (os/cwd) sep path)))

(defn mkdir
  [path]
  (def parts (apart path))
  (when (and (index-of (os/which) [:mingw :windows])
             (string/has-suffix? ":\\" (first parts)))
    (put parts 1 (string (get parts 0) (get parts 1)))
    (array/remove parts 0))
  (var res false)
  (def pwd (os/cwd))
  (each part parts
    (set res (os/mkdir part))
    (os/cd part))
  (os/cd pwd)
  res)

(defn parent
  [path]
  (def parts (apart path))
  (if (empty? parts)
    parts
    (do
      (put parts 0 (string/replace sep "" (first parts)))
      (string/join (array/slice parts 0 -2) sep))))

(defn change-syspath
  [path]
  (def ap (abspath path))
  (unless (= :directory (os/stat ap :mode))
    (mkdir ap))
  (setdyn *syspath* ap))

(defn copy
  [src dest]
  (if (= :windows (os/which))
    (let [dir? (= (os/stat src :mode) :directory)]
      (os/shell (string "C:\\Windows\\System32\\xcopy.exe" " "
                        src
                        " "
                        dest
                        (when dir? (string sep (last (apart src))))
                        " "
                        "/y /s /e /i > nul")))
    (os/execute ["cp" "-rf" src dest] :px)))

(defn fetch-git [&named url tag dir]
  (assert url "function requires :url argument")
  (assert dir "function requires :dir argument")
  (default tag "HEAD")
  (def sha? (= [] (peg/match '(between 7 40 :h) tag)))
  (def devnull (devnull))
  (def stdio {:out devnull :err devnull})
  (if (= "HEAD" tag)
    (exec :git stdio "clone" "--depth" "1" url dir)
    (if (not sha?)
      (exec :git stdio "clone" "--branch" tag "--depth" "1" url dir)
      (do
        (exec :git stdio "clone" "--filter" "blob:none" "--no-checkout" url dir)
        (exec :git stdio "-C" dir "fetch" "origin" tag)
        (exec :git stdio "-C" dir "checkout" tag))))
  dir)

(defn fetch-dep [parent-dir dep]
  (def temp-dir "tmp")
  (def {:url url
        :tag tag
        :prefix prefix
        :files files} dep)
  (unless url
    (error "fetched bundles need a :url key"))
  (def pwd (os/cwd))
  (defer (do
           (os/cd pwd)
           (rmrf temp-dir))
    (os/mkdir temp-dir)
    (def dest-dir (string parent-dir (when prefix (string sep prefix))))
    (print "vendoring " url " to " dest-dir)
    (def src-dir (if (string/has-prefix? "file::" url)
                   (slice url 6)
                   (fetch-git :url url :tag tag :dir temp-dir)))
    (each file files
      (def from (string src-dir sep file))
      (def to (string dest-dir sep file))
      (mkdir (parent to))
      (print "  copying " from " to " to)
      (copy from to))))

(defn load-info
  [&opt dir]
  (default dir ".")
  (def info-path1 (string/join [dir "bundle" "info.jdn"] sep))
  (def info-path2 (string/join [dir "info.jdn"] sep))
  (or (slurp-maybe info-path1) (slurp-maybe info-path2)))

(defn load-meta
  [&opt dir]
  (default dir ".")
  (when-let [info (load-info dir)]
   (parse info)))

(defn local-hook
  [name & args]
  (def [ok? module] (protect (require "/bundle" :fresh true)))
  (when-let [hookf (and ok? (module/value module (symbol name)))]
    (apply hookf args)
    true))

(defn save-info
  [jdn &opt dir]
  (default dir ".")
  (def info-path1 (string/join [dir "bundle" "info.jdn"] sep))
  (def info-path2 (string/join [dir "info.jdn"] sep))
  (or (spit-maybe info-path1 jdn) (spit-maybe info-path2 jdn)))

(defn version
  []
  (if (string/has-prefix? (os/realpath (dyn :syspath)) this-file)
    (get (bundle/manifest "jeep") :version)
    (do
      (def [r w] (os/pipe))
      (def devnull (devnull))
      (def bundle-root (-> this-file os/realpath parent parent))
      (def ver "local")
      (os/cd bundle-root)
      (def [ok? res] (protect (exec :git {:out w} "describe" "--always" "--dirty")))
      (:close w)
      (if ok?
        (string ver "-" (string/trim (ev/read r :all)))
        ver))))
