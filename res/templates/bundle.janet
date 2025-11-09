# Use `jeep prep build` to copy the necessary build files from Spork
# (import ./spork/declare-cc :as declare)

(def- build-dir "_build")
(def- seps {:windows "\\" :mingw "\\" :cygwin "\\"})
(def- s (get seps (os/which) "/"))
(def- esc (cond (os/getenv "PSModulePath")
                "`"
                (index-of (os/which) [:mingw :windows])
                "^"
                # default
                "\\"))
(def- pathg ~{:main     (* :relpath (? :sep) -1)
              :relpath  (* :part (any (* :sep :part)))
              :sep      ,s
              :part     (* (+ :quoted :unquoted) (> (+ :sep -1)))
              :quoted   (* `"`
                           (% (some (+ (* ,esc ,esc)
                                       (* ,esc `"`)
                                       (* (! `"`) '1))))
                           `"`)
              :unquoted (% (some (+ :escaped (* (! (set `"\/ `)) '1))))
              :escaped  (* ,esc '1)})

(defn- add-path [paths dest &opt src]
  (def bits (peg/match pathg dest))
  (assert bits "invalid path")
  (def ks @[])
  (each b bits
    (array/push ks b)
    (unless (get-in paths ks)
      (put-in paths ks @{})))
  (when src
    (put-in paths ks src)))

(defn- build-exes [manifest &]
  (def exes (get-in manifest [:info :artifacts :executables] []))
  (print "building native executables is not implemented")
  (each exe exes
    (cond
      # uncomment when building quickbins
      # (get exe :quickbin)
      # (declare/quickbin (string build-dir s (get exe :name)) (get exe :entry))
      # default
      nil)))

(defn- build-nats [manifest &]
  (def nats (get-in manifest [:info :artifacts :natives] []))
  (print "building native libraries is not implemented")
  (each nat nats
    nil))

(defn build [manifest &]
  (os/mkdir build-dir)
  (build-nats manifest)
  (build-exes manifest))

(defn- install-exes [manifest &]
  (def exes (get-in manifest [:info :artifacts :executables] []))
  (each exe exes
    (bundle/add-bin manifest (string build-dir s (get exe :name)))))

(defn- install-libs [manifest &]
  (def to-make @{})
  (def libs (get-in manifest [:info :artifacts :libraries] []))
  (each lib libs
    (def ks @[])
    (def prefix (get lib :prefix))
    (add-path to-make prefix)
    (def paths (get lib :paths))
    (each p paths
      (add-path to-make (string prefix s p) p)))
  (defn add-tree [tree path]
    (eachp [k v] tree
      (if (table? v)
        (do
          (def new-path (if (empty? path) k (string path s k)))
          (bundle/add-directory manifest new-path)
          (add-tree v new-path))
        (bundle/add manifest v (string path s k)))))
  (add-tree to-make ""))

(defn- install-mans [manifest &]
  (def mans (get-in manifest [:info :artifacts :manpages] []))
  (each m mans
    (def bits (peg/match pathg))
    (var dir nil)
    (each b bits
      (if (nil? dir)
        (set dir b)
        (set dir (string dir s b)))
      (os/mkdir dir))
    (bundle/add-file manifest m)))

(defn- install-nats [manifest &]
  (print "installing native libraries is not implemented"))

(defn- install-scrs [manifest &]
  (def scrs (get-in manifest [:info :artifacts :scripts] []))
  (each scr scrs
    (bundle/add-bin manifest (get scr :path))))

(defn install [manifest &]
  (install-exes manifest)
  (install-libs manifest)
  (install-mans manifest)
  (install-nats manifest)
  (install-scrs manifest))
