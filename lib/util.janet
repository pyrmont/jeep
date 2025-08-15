(defdyn *gitpath* "What git command to use to fetch dependencies")
(defdyn *tarpath* "What tar command to use to fetch dependencies")
(defdyn *curlpath* "What curl command to use to fetch dependencies")

(def colours {:green "\e[32m" :red "\e[31m"})

(def sep (get {:windows "\\" :cygwin "\\" :mingw "\\"} (os/which) "/"))

(def pathg ~{:main (* (+ :abspath :relpath) -1)
             :abspath (* :root (any :relpath))
             :relpath (* :part (any (* :sep :part)))
             :root '(+ "/" (* (? (* :a ":")) `\`))
             :sep  ,sep
             :part (* (+ :quoted :unquoted) (> (+ :sep -1)))
             :quoted (* `"` '(some (+ `\\` `\"` (* (! `"`) 1))) `"`)
             :unquoted '(some (+ :escaped (* (! (set `"\/ `)) 1)))
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
  (default stdio {})
  (os/execute [(dyn (keyword cmd "path") (string cmd)) ;args] :px stdio))

(defn fexists?
  [p]
  (= :file (os/stat p :mode)))

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

(defn mkdir
  [path]
  (def parts (apart path))
  (var res false)
  (def pwd (os/cwd))
  (each part parts
    (set res (os/mkdir part))
    (os/cd part))
  (os/cd pwd)
  res)

(defn parent
  [path]
  (string/join (array/slice (apart path) 0 -2) sep))

(defn change-syspath
  [path]
  (def abspath (if (abspath? path)
                 path
                 (string (os/cwd) sep path)))
  (unless (= :directory (os/stat abspath :mode))
    (mkdir abspath))
  (setdyn *syspath* abspath))

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
  (defn vendor [vendor-dir dep]
    (def {:url url
          :tag tag
          :prefix prefix
          :include includes
          :exclude excludes} dep)
    (unless url
      (error "vended dependencies need a :url key"))
    (default tag "HEAD")
    (def sha? (= [] (peg/match '(between 7 40 :h) tag)))
    (def devnull (devnull))
    (def stdio {:out devnull :err devnull})
    (def dest-dir (string vendor-dir (when prefix (string sep prefix))))
    (print "vendoring " url " to " dest-dir)
    (defer (rmrf temp-dir)
      (os/mkdir temp-dir)
      (if (= "HEAD" tag)
        (exec :git stdio "clone" "--depth" "1" url temp-dir)
        (if (not sha?)
          (exec :git stdio "clone" "--branch" tag "--depth" "1" url temp-dir)
          (do
            (exec :git stdio "clone" "--filter" "blob:none" "--no-checkout" url temp-dir)
            (exec :git stdio "-C" temp-dir "fetch" "origin" tag)
            (exec :git stdio "-C" temp-dir "checkout" tag))))
      (when excludes
        (each exclude excludes
          (rmrf (string/join [temp-dir exclude] sep))))
      (def files (if includes includes (os/dir temp-dir)))
      (each file files
        (def from (string temp-dir sep file))
        (def to (string dest-dir sep file))
        (if (= :directory (os/stat from :mode))
          (mkdir to)
          (mkdir (parent to)))
        (print "  copying " from " to " to)
        (copy from to))))
  (def vendored (get (load-meta) :vendored))
  (each [dir deps] (pairs vendored)
    (each d deps
      (vendor dir d))))
