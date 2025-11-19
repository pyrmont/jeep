(import ../info)
(import ../util)
(import ../../deps/musty)

# Help strings
(def- helps
  {:name
   `The name of the bundle to create. Used as both the directory name and the
   bundle name in the info file.`
   :alias
   `Use the aliased path when creating the <type> of file. Multiple values can
   be entered. Valid values are 'bundle' or 'info'. By default, the aliased
   path is used for the info file only.`
   :art-exe
   `Create scaffold for producing an executable artifact.`
   :art-lib
   `Create scaffold for producing a library artifact.`
   :art-man
   `Create scaffold for producing a manpage artifact.`
   :art-nat
   `Create scaffold for producing a native library artifact.`
   :art-scr
   `Create scaffold for producing an executable script artifact.`
   :author
   `The author name for the bundle. If not specified, attempts to read from
   git config (user.name).`
   :bare
   `Create an info file only.`
   :desc
   `A short description of the bundle's purpose.`
   :forge
   `The URL of the forge where the bundle will be hosted (will be used to infer
    the bundle's URL and repository if not overridden).`
   :license
   `The license type for the bundle. Jeep can generate license files for
   certain licenses. See 'man jeep-new' for a complete list.`
   :no-alias
   `Create the bundle script or info file in its non-aliased path. Valid values
   are 'bundle' or 'info'.`
   :no-alias
   `Do not use the aliased path when creating the <type> of file. Multiple
   values can be entered. Valid values are 'bundle' or 'info'. By default, the
   aliased path is used for the info file only.`
   :no-ask
   `Do not ask for missing options.`
   :repo
   `The repository URL of the bundle.`
   :templates
   `A directory containing the templates to use. When generating files, Jeep
   will check it first for 'licenses/', '.gitignore', 'README.md', 'binscript',
   'bundle.janet, 'info.jdn' and 'project.janet'.`
   :url
   `The URL of the bundle.`
   :about
   `Creates a new Janet bundle.`
   :help
   `Create a new Janet bundle.`})

# Configuration
(def config
  {:rules [:name {:req? true
                  :help (helps :name)}
           "--author" {:kind :single
                       :short "a"
                       :proxy "name"
                       :help (helps :author)}
           "--desc" {:kind :single
                     :short "d"
                     :proxy "text"
                     :help (helps :desc)}
           "--license" {:kind :single
                        :short "i"
                        :proxy "type"
                        :help (helps :license)}
           "----"
           "--forge" {:kind :single
                      :short "f"
                      :proxy "url"
                      :help (helps :forge)}
           "--url" {:kind :single
                    :short "u"
                    :help (helps :url)}
           "--repo" {:kind :single
                     :short "r"
                     :proxy "url"
                     :help (helps :repo)}
           "----"
           "--executable" {:kind :flag
                           :short "e"
                           :help (helps :art-exe)}
           "--library" {:kind :flag
                        :short "l"
                        :help (helps :art-lib)}
           "--manpage" {:kind :flag
                        :short "m"
                        :help (helps :art-man)}
           "--native" {:kind :flag
                       :short "n"
                       :help (helps :art-nat)}
           "--script" {:kind :flag
                       :short "s"
                       :help (helps :art-scr)}
           "----"
           "--alias" {:kind :multi
                      :short "k"
                      :proxy "type"
                      :help (helps :alias)}
           "--bare" {:kind :flag
                     :short "b"
                     :help (helps :bare)}
           "--no-alias" {:kind :multi
                         :short "K"
                         :help (helps :no-alias)}
           "--no-ask" {:kind :flag
                       :short "A"
                       :help (helps :no-ask)}
           "--templates" {:kind :single
                          :proxy "dir"
                          :short "t"
                          :help (helps :templates)}
           "----"]
   :info {:about (helps :about)}
   :help (helps :help)})

(def- this-file (os/realpath (dyn :current-file)))
(def- template-dir
  (string (util/parent this-file 3) util/sep "res" util/sep "templates"))

# state
(def- to-make @[])
(def- to-move @[])
(def- to-undo @[])

(defn- queue-make
  [path-bits &named contents mode backup?]
  (def path (string/join path-bits util/sep))
  (if (os/stat path :mode)
    (when backup?
      (def backup (string path ".original"))
      (assertf (nil? (os/stat backup :mode))
               "cannot back up %s to %s, file exists" path backup)
      (array/push to-move [path backup])
      (array/push to-make [path contents mode]))
    (array/push to-make [path contents mode])))

(defn- queue-move
  [src-bits dest-bits &named backup?]
  (array/push to-move [(string/join src-bits util/sep)
                       (string/join dest-bits util/sep)]))

(defn- queue-undo
  [op path &opt more]
  (array/push to-undo [op path more]))

(defn- get-ask
  [name dict k &opt dflt]
  (if (has-key? dict k)
    (break (get dict k)))
  (def dflt-desc (cond (= "" dflt) "<empty>" (nil? dflt) "nil" dflt))
  (def k-desc
    (case k
      "version"
      "the version"
      "desc"
      "a short description"
      "author"
      "the author"
      "license"
      "the license"
      "url"
      "the URL"
      "repo"
      "the repository URL"
      (error "unrecognised key")))
  (print k-desc)
  (print name)
  (print dflt-desc)
  (def p (string/format "Enter %s of '%s' (default: %s): " k-desc name dflt-desc))
  (def resp (-> (getline p) (string/trim)))
  (def res
    (if (empty? resp)
      dflt
      (cond
        (and (= (chr `"`) (first resp))
             (= (chr `"`) (last resp)))
        (string/slice resp 1 -2)
        (and (= (chr `'`) (first resp))
             (= (chr `'`) (last resp)))
        (string/slice resp 1 -2)
        # default
        resp)))
  (print (util/colour :green (string "Set " k-desc " to '" res "'")))
  res)

(defn get-author
  []
  (def home (os/getenv "HOME"))
  (def oldskool (string home util/sep ".gitconfig"))
  (def newskool (string home util/sep ".config" util/sep "git" util/sep "config"))
  (def config (cond
                (= :file (os/stat oldskool :mode))
                (slurp oldskool)
                (= :file (os/stat newskool :mode))
                (slurp newskool)))
  (-?>> config (peg/match ~{:main (* (thru "name = ") '(to "\n"))}) array/pop))

(defn- make-artifacts
  [dir meta opts]
  (when (get opts :bare?) (break))
  (when (get meta :exe?)
    (queue-make [dir "lib"]))
  (when (get meta :lib?)
    (queue-make [dir "lib"])
    (queue-make [dir "init.janet"] :contents ""))
  (when (get meta :man?)
    (queue-make [dir "man"])
    (queue-make [dir "man" "man1"])
    (def contents "Visit <pyrmont.github.io/predoc> for more information about Predoc.")
    (def filename (string (get meta :name) ".1.predoc"))
    (queue-make [dir "man" "man1" filename] :contents contents))
  (when (get meta :nat?)
    (queue-make [dir "src"]))
  (when (get meta :scr?)
    (queue-make [dir "bin"])
    (queue-make [dir "lib"])
    (queue-make [dir "lib" "cli.janet"] :contents "")
    (def t (slurp (get-in opts [:files :binscript])))
    (def contents (musty/render t meta))
    (queue-make [dir "bin" (get meta :name)] :contents contents :mode 8r755)))

(defn- make-bundle-script
  [dir meta opts]
  (when (get opts :bare?) (break))
  (def t (slurp (get-in opts [:files :bundle-script])))
  (def contents (musty/render t meta))
  (if (get-in opts [:aliases :bundle])
    (queue-make [dir "bundle.janet"] :contents contents)
    (do
      (when (get-in opts [:aliases :info])
        (queue-make [dir "bundle"])) # bundle will already exist
      (queue-make [dir "bundle" "init.janet"] :contents contents))))

(defn- make-gitignore
  [dir meta opts]
  (when (get opts :bare?) (break))
  (def t (slurp (get-in opts [:files :gitignore])))
  (def contents (musty/render t meta))
  (queue-make [dir ".gitignore"] :contents contents))

(defn- make-info-file
  [dir meta opts]
  (def t (slurp (get-in opts [:files :info-file])))
  (def base (musty/render t meta))
  (def contents
    (if (or (has-key? meta :dependencies)
            (has-key? meta :vendored)
            (has-key? meta :artifacts))
      (do
        (def jdn (info/jdn-str->jdn-arr base))
        (when (has-key? meta :dependencies)
          (info/upd-in jdn [:dependencies] :to (get meta :dependencies)))
        (when (has-key? meta :vendored)
          (info/upd-in jdn [:vendored] :to (get meta :vendored)))
        (when (has-key? meta :artifacts)
          (each art [:executables :libraries :manpages :natives :scripts]
            (def v (get-in meta [:artifacts art]))
            (when v
              (info/upd-in jdn [:artifacts art] :to v))))
        (info/jdn-arr->jdn-str jdn))
      base))
  (if (get-in opts [:aliases :info])
    (queue-make [dir "info.jdn"] :contents contents)
    (do
      (queue-make [dir "bundle"])
      (queue-make [dir "bundle" "info.jdn"] :contents contents))))

(defn- make-license
  [dir meta opts]
  (when (get opts :bare?) (break))
  (def ldir (get-in opts [:files :licenses]))
  (def lpath (string ldir util/sep (get meta :license) ".txt"))
  (when (= :file (os/stat lpath :mode))
    (def t (slurp lpath))
    (def contents (musty/render t meta))
    (queue-make [dir "LICENSE"] :contents contents)))

(defn- make-others
  [dir meta opts]
  (when (get opts :bare?) (break))
  (queue-make [dir "test"]))

(defn- make-project
  [dir meta opts]
  (when (get opts :bare?) (break))
  (def t (slurp (get-in opts [:files :project-file])))
  (def contents (musty/render t meta))
  (def backup? (get-in opts [:backups "project.janet"]))
  (queue-make [dir "project.janet"] :contents contents :backup? backup?))

(defn- make-readme
  [dir meta opts]
  (when (get opts :bare?) (break))
  (def t (slurp (get-in opts [:files :readme])))
  (def contents (musty/render t meta))
  (queue-make [dir "README.md"] :contents contents))

(defn- setup-aliases
  [aliases no-aliases]
  (assert (not (and (index-of "bundle" aliases)
                    (index-of "bundle" no-aliases)))
          "cannot set 'bundle' in --alias and --no-alias")
  (assert (not (and (index-of "info" aliases)
                    (index-of "info" no-aliases)))
          "cannot set 'info' in --alias and --no-alias")
  (def res @{:bundle false :info true})
  (if (index-of "bundle" aliases)
    (put res :bundle true))
  (if (index-of "info" aliases)
    (put res :info true))
  (if (index-of "bundle" no-aliases)
    (put res :bundle false))
  (if (index-of "info" no-aliases)
    (put res :info false))
  res)

(defn- setup-forge
  [forge]
  (cond
    (nil? forge)
    "https://example.org/"
    (string/has-prefix? "https://" forge)
    (string forge (unless (string/has-suffix? "/" forge) "/"))
    (string/has-prefix? "http://" forge)
    (string forge (unless (string/has-suffix? "/" forge) "/"))
    # default
    (string "https://" forge (unless (string/has-suffix? "/" forge) "/"))))

(defn- setup-paths
  [user-dir]
  (def dir (or user-dir template-dir))
  (def res @{})
  (def bs-path (string dir util/sep "bundle.janet"))
  (if (= :file (os/stat bs-path :mode))
    (put res :bundle-script bs-path)
    (put res :bundle-script (string template-dir util/sep "bundle.janet")))
  (def gi-path (string dir util/sep ".gitignore"))
  (if (= :file (os/stat gi-path :mode))
    (put res :gitignore gi-path)
    (put res :gitignore (string template-dir util/sep ".gitignore")))
  (def if-path (string dir util/sep "info.jdn"))
  (if (= :file (os/stat if-path :mode))
    (put res :info-file if-path)
    (put res :info-file (string template-dir util/sep "info.jdn")))
  (def ld-path (string dir util/sep "licenses"))
  (if (= :directory (os/stat ld-path :mode))
    (put res :licenses ld-path)
    (put res :licenses (string template-dir util/sep "licenses")))
  (def pf-path (string dir util/sep "project.janet"))
  (if (= :file (os/stat pf-path :mode))
    (put res :project-file pf-path)
    (put res :project-file (string template-dir util/sep "project.janet")))
  (def rm-path (string dir util/sep "README.md"))
  (if (= :file (os/stat rm-path :mode))
    (put res :readme rm-path)
    (put res :readme (string template-dir util/sep "README.md")))
  (def sf-path (string dir util/sep "binscript"))
  (if (= :file (os/stat sf-path :mode))
    (put res :binscript sf-path)
    (put res :binscript (string template-dir util/sep "binscript")))
  res)

(defn create-bundle
  [opts params &opt dir defaults backups]
  # return value
  (var created? true)
  # configure defaults
  (default defaults @{})
  # reset global state
  (array/clear to-make)
  (array/clear to-move)
  (array/clear to-undo)
  # setup name
  (def name (get params :name))
  # setup target directory
  (def tdir (or dir name))
  # setup bundle opts
  (def bopts @{})
  (put bopts :bare? (not (nil? (get opts "bare"))))
  (put bopts :ask? (nil? (get opts "no-ask")))
  (put bopts :files (setup-paths (get opts "templates")))
  (put bopts :aliases (setup-aliases (get opts "alias" [])
                                     (get opts "no-alias" [])))
  (put bopts :backups backups)
  # setup answer function
  (def answer
    (if (get bopts :ask?)
      (partial get-ask name opts)
      (partial get opts)))
  # setup bundle metadata
  (def meta @{})
  (put meta :name name)
  (put meta :version (answer "version" (get defaults :version "DEVEL")))
  (put meta :desc (answer "desc" (get defaults :description "")))
  (put meta :author (answer "author" (get defaults :author (get-author))))
  (put meta :year (os/strftime "%Y" (os/time) true))
  (put meta :license (answer "license" (get defaults :license "MIT")))
  (def url (string (setup-forge (get opts "forge")) name))
  (put meta :url (answer "url" (get defaults :url url)))
  (put meta :repo (answer "repo" (get defaults :repo (string "git+" url))))
  (put meta :exe? (get opts "executable"))
  (put meta :lib? (get opts "library"))
  (put meta :man? (get opts "manpage"))
  (put meta :nat? (get opts "native"))
  (put meta :scr? (get opts "script"))
  # add structured data from defaults if present
  (when (has-key? defaults :dependencies)
    (put meta :dependencies (get defaults :dependencies)))
  (when (has-key? defaults :vendored)
    (put meta :vendored (get defaults :vendored)))
  (when (has-key? defaults :artifacts)
    (put meta :artifacts (get defaults :artifacts)))
  # make target directory
  (unless dir (queue-make [name]))
  # make files
  (make-info-file tdir meta bopts)
  # make optional files
  (make-bundle-script tdir meta bopts)
  (make-artifacts tdir meta bopts)
  (make-gitignore tdir meta bopts)
  (make-license tdir meta bopts)
  (make-project tdir meta bopts)
  (make-readme tdir meta bopts)
  (make-others tdir meta bopts)
  # update file system
  (try
    (do
      (each [src dest] to-move
        (queue-undo :move src dest)
        (os/rename src dest)
        (print "moved " src " to " dest))
      (each [path contents mode] to-make
        (queue-undo :make path)
        (when (def kind (os/stat path :mode))
          (errorf "%s exists at %s" kind path))
        (if (nil? contents)
          (if (util/mkdir path)
            (print "created " path util/sep)
            (errorf "failed to make directory at %s" path))
          (do
            (spit path contents)
            (print "created " path)))
        (when mode
          (os/chmod path mode))))
    ([e f]
     (set created? false)
     (print "error encountered, undoing bundle creation...")
     (each action (reverse to-undo)
       (case (first action)
         :make
         (do
           (def path (get action 1))
           (if (= :directory (os/stat path :mode))
             (os/rmdir path)
             (os/rm path))
           (print "removed " path))
         :move
         (do
           (def old (get action 1))
           (def new (get action 2))
           (os/rename new old)
           (print "renamed " new " to " old))
         # default
         (error "unrecognised action")))
     (debug/stacktrace f e "error: ")))
  # return whether creation succeeded
  created?)

(defn run
  [args]
  (def opts (get-in args [:sub :opts] {}))
  (def params (get-in args [:sub :params] {}))
  # check directory
  (def name (get params :name))
  (assertf (nil? (os/stat name)) "directory '%s' already exists" name)
  # create bundle
  (create-bundle opts params)
  (print "Bundle created."))
