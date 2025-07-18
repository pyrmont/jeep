(defdyn *gitpath* "What git command to use to fetch dependencies")
(defdyn *tarpath* "What tar command to use to fetch dependencies")
(defdyn *curlpath* "What curl command to use to fetch dependencies")

(def colours {:green "\e[32m" :red "\e[31m"})

(def sep (get {:windows "\\" :cygwin "\\" :mingw "\\"} (os/which) "/"))

(def pathg ~{:main (* (? :root) (some (+ :sep :part)) -1)
             :root '(+ "/" (* (? (* :a ":")) `\`))
             :sep  ,sep
             :part (* (+ :quoted :unquoted) (> (+ :sep -1)))
             :quoted (* `"` '(some (+ `\\` `\"` (* (! `"`) 1))) `"`)
             :unquoted '(some (+ :escaped (* (! :sep) 1)))
             :escaped (* `\` 1)})

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
  [c text]
  (if (os/isatty)
    (string (get colours c "\e[0m") text "\e[0m")
    text))

(defn copy
  [src dest]
  (if (= :windows (os/which))
    (let [isdir (= (os/stat src :mode) :directory)]
      (os/shell (string "C:\\Windows\\System32\\xcopy.exe" " "
                        src " "
                        dest " "
                        "/y /s /e /i > nul")))
    (os/execute ["cp" "-rf" src dest] :px)))

(defn exec
  [cmd stdio & args]
  (default stdio {})
  (os/execute [(dyn (keyword cmd "path") (string cmd)) ;args] :px stdio))

(defn fexists?
  [p]
  (= :file (os/stat p :mode)))

(defn mkdir-from-parts
  [parts]
  (def pwd (os/cwd))
  (each part parts
    (os/mkdir part)
    (os/cd part))
  (os/cd pwd))

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

(defn change-syspath
  [path]
  (def abspath (if (abspath? path)
                 path
                 (string (os/cwd) sep path)))
  (unless (= :directory (os/stat abspath :mode))
    (mkdir-from-parts (apart abspath)))
  (setdyn *syspath* abspath))

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
  (def [ok module] (protect (require "/bundle")))
  (when-let [hookf (and ok (module/value module (symbol name)))]
    (apply hookf @{} args)))

(defn save-info
  [jdn &opt dir]
  (default dir ".")
  (def info-path1 (string/join [dir "bundle" "info.jdn"] sep))
  (def info-path2 (string/join [dir "info.jdn"] sep))
  (or (spit-maybe info-path1 jdn) (spit-maybe info-path2 jdn)))

(defn vendor-deps
  []
  (def temp-dir "tmp")
  (defn is-tarball? [url]
    (or (string/has-suffix? ".gz" url)
        (string/has-suffix? ".tar" url)))
  (defn vendor [vendor-dir dep]
    (def {:url url
          :tag tag
          :prefix prefix
          :include includes
          :exclude excludes} dep)
    (unless url
      (error "vended dependencies need a :url key"))
    (default tag "HEAD")
    (def tarball (if (is-tarball? url) url (string url "/archive/" tag ".tar.gz")))
    (def dest-dir (string vendor-dir (when prefix (string sep prefix))))
    (def filename (-> (string/split "/" tarball) last))
    (print "vendoring " tarball " to " dest-dir)
    (defer (rmrf temp-dir)
      (os/mkdir temp-dir)
      (def tar-file (string/join [temp-dir filename] sep))
      (exec :curl nil "-sL" tarball "-o" tar-file)
      (exec :tar nil "xf" tar-file "-C" temp-dir "--strip-components" "1")
      (rmrf tar-file)
      (when excludes
        (each exclude excludes
          (rmrf (string/join [temp-dir exclude] sep))))
      (def files (if includes includes (os/dir temp-dir)))
      (each file files
        (def file-parts (apart file))
        (def from (string/join [temp-dir ;file-parts] sep))
        (def to (string/join [dest-dir ;file-parts] sep))
        (def to-parts (apart to))
        (if (= :directory (os/stat from :mode))
          (mkdir-from-parts to-parts)
          (mkdir-from-parts (array/slice to-parts 0 -2)))
        (print "  copying " from " to " to)
        (copy from to))))
  (def vendored (get (load-meta) :vendored))
  (each [dir deps] (pairs vendored)
    (each d deps
      (vendor dir d))))
