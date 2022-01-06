(def DEFAULT-META "~/.jeep/new/meta.janet")
(def DEFAULT-GITIGNORE "~/.jeep/new/.gitignore")


# File paths

(def dir-peg (peg/compile
    ~{:main    (* (+ :rpath :apath) -1)
      :sep     "/"
      :invalid (+ :sep)
      :root    ':sep
      :rpath   (* (not :root) :path)
      :apath   (* :root (? :path))
      :path    (* :dir (any (* :sep :dir)) (? :sep))
      :dir     '(some (if-not :invalid 1))}))


(defn- base-dir [path]
  (-> (peg/match dir-peg path) last))


(defn- expand [path]
  (if (= 126 (first path)) # ASCII code for ~
    (string/replace "~" (os/getenv "HOME") path)
    path))


# Interrogation

(defn- ask [q &opt dflt]
  (def answer (-> (string q (when dflt (string " [" dflt "]")) ": ")
                  getline
                  string))
  (if (= "\n" answer)
    dflt
    (let [trimmed (string/trim answer)]
      (unless (empty? trimmed)
        trimmed))))


(defn- choose [q choices]
  (var answer nil)
  (while (nil? answer)
    (print "Please choose one of the following:")
    (each choice (sort (values choices))
      (print " " choice))
    (def choice (-> (getline (string q ": ")) string/trim))
    (if (choices choice)
      (set answer choice)
      (print "There is no choice matching that selection.")))
  answer)


(defn- read-meta [path]
  (def full-path (expand path))
  (def meta (when (os/stat full-path) (-> (slurp full-path) eval-string)))
  (if (and meta (struct? meta))
    meta
    (do
      (when meta
        (eprint "[WARN] File " full-path " did not contain a valid Janet struct"))
      {})))


(defn- repo-url [url]
  (when (and url
             (or (string/has-prefix? "https://" url)
                 (string/has-prefix? "http://" url)))
    (string "git+" url)))


(defn- quiz [{:name uname :desc udesc :author uauthor :license ulicense :url uurl :repo urepo :kind ukind} &opt meta auto?]
  (default meta {})
  (default auto? false)
  (def kinds {"1" :executable "exe" :executable "2" :native "nat" :native "3" :source "src" :source})
  (var name (or uname (meta :name)))
  (var desc (or udesc (meta :desc)))
  (var author (or uauthor (meta :author)))
  (var license (or ulicense (meta :license)))
  (var url (or uurl (meta :url)))
  (var repo (or urepo (meta :repo)))
  (var kind (kinds (or ukind (meta :kind))))
  (unless auto?
      (print "Enter a blank space to clear an option with a default.")
      (set name (ask "Name" name))
      (set desc (ask "Description" desc))
      (set author (ask "Author" author))
      (set license (ask "License" license))
      (set url (ask "URL" url))
      (set repo (ask "Repository" (or repo (repo-url url))))
      (set kind (-> (choose "Type" {"1" "(1) executable" "2" "(2) native" "3" "(3) source"}) (kinds))))
  {:name name
   :desc desc
   :author author
   :license license
   :url url
   :repo repo
   :kind kind})


# File creation

(defn- create-dirs [path]
  (var made-dir? false)
  (def start (os/cwd))
  (def dirs (peg/match dir-peg path))
  (each dir dirs
    (def [exists? _] (protect (os/cd dir)))
    (unless exists?
      (os/mkdir dir)
      (set made-dir? true)))
  (os/cd start)
  (def real-path (os/realpath path))
  (if made-dir?
    [true real-path]
    [false real-path]))


(defn- create-gitignore-file [project-dir src]
  (unless (dyn :no-git)
    (def to (string project-dir "/" ".gitignore"))
    (if (not (nil? (os/stat to)))
      [false to]
      (do
        (def from (expand src))
        (if (-?> (os/stat from) (get :mode) (= :file))
          (spit to (slurp from))
          (spit to ""))
        [true to]))))


(defn- create-project-file [project-dir opts]
  (def to (string project-dir "/" "project.janet"))
  (if (not (nil? (os/stat to)))
    [false to]
    (do
      (def answers {:name (base-dir project-dir)
                    :desc (opts "project-desc")
                    :author (opts "project-author")
                    :license (opts "project-license")
                    :url (opts "project-url")
                    :repo (opts "project-repo")
                    :kind (opts "type")})
      (def details (quiz answers (read-meta (opts "metadata")) (opts "auto")))
      (def buf @"")
      (with-dyns [:out buf]
        (print `(declare-project`)
        (print `  :name "` (details :name) `"`)
        (print `  :description "` (details :desc) `"`)
        (print `  :author "` (details :author) `"`)
        (print `  :license "` (details :license) `"`)
        (print `  :url "` (details :url) `"`)
        (print `  :repo "` (details :repo) `"`)
        (print `  :dependencies [])`)
        (print)
        (case (details :kind)
          :executable
          (do
            (print `(declare-executable`)
            (print `  :name "` (string/ascii-lower (details :name)) `"`)
            (print `  :entry ""`)
            (print `  :install true)`))

          :native
          (do
            (print `(declare-native`)
            (print `  :name "` (string/ascii-lower (details :name)) `"`)
            (print `  :clfags [;default-cflags]`)
            (print `  :lflags [;default-lflags]`)
            (print `  :headers []`)
            (print `  :source [])`))

          :source
          (do
            (print `(declare-source`)
            (print `  :source [])`))))
      (spit to buf)
      [true to])))


(defn- create-test-dir [project-dir]
  (unless (dyn :no-tests)
    (create-dirs (string project-dir "/" "test"))))


# Verification

(defn- dir-value [input]
  (when (peg/match dir-peg input)
    (def path (expand input))
    (def stats (os/stat path))
    (if (nil? stats)
      path
      (when (= :directory (stats :mode))
        (os/realpath path)))))


(defn- type-value [input]
  (case (string/ascii-lower input)
    "exe" "exe"
    "nat" "nat"
    "src" "src"))


# Utilities

(defn- clean-up [events]
  (each event events
    (unless (nil? event)
      (def [made? path] event)
      (when made?
        (def dir? (= :directory (os/stat path)))
        (if dir?
          (os/rmdir path)
          (os/rm path))))))


(defn- color [k s]
  (def code
    (case k
      :green "\u001b[32;1m"
      :yellow "\u001b[33m"))
  (if (dyn :no-color)
    s
    (string code s "\u001b[0m")))


(defn- log [event events]
  (array/push events event))


(defn- report [events]
  (each event events
    (unless (nil? event)
      (def [made? path] event)
      (print (if made? (color :green "Created") (color :yellow "Skipped")) "  " path)))
  true)


(defn- cmd-fn [meta opts params]
  (def events @[])
  (var reported? false)
  (setdyn :no-color (opts "no-color"))
  (setdyn :no-tests (opts "no-tests"))
  (setdyn :no-git (opts "no-git"))
  (defer (unless reported? (clean-up log))
    (log (create-dirs (params :dir)) events)
    (def project-dir (get-in events [0 1]))
    (log (create-project-file project-dir opts) events)
    (log (create-gitignore-file project-dir (opts "gitignore")) events)
    (log (create-test-dir project-dir) events)
    (set reported? (report events))))


(def config
  {:rules ["--auto" {:kind  :flag
                     :help  `Create a project without prompting. Will use the command
                            line options and the values from --meta to complete the
                            project.janet file.`
                     :short "a"}
           "--gitignore" {:kind    :single
                          :help    `A .gitignore file placed into the project
                                   directory`
                          :name    "PATH"
                          :default DEFAULT-GITIGNORE}
           "--metadata" {:kind    :single
                         :help    `The path to a Janet file that contains metadata used
                                  to complete the declare-project section of the
                                  project.janet.`
                         :name    "PATH"
                         :default DEFAULT-META}
           "--no-color" {:kind :flag
                         :help "Do not use colored output."}
           "--no-tests" {:kind :flag
                         :help "Do not create test directory."}
           "--no-git" {:kind :flag
                       :help "Do not create .gitignore file."}
           "--project-author" {:kind :single
                               :help "The value to use for the project author."
                               :name "NAME"}
           "--project-desc" {:kind :single
                             :help "The value to use for the project description."
                             :name "DESC"}
           "--project-license" {:kind :single
                                :help "The value to use for the project license."
                                :name "LICENSE"}
           "--project-repo" {:kind :single
                             :help "The value to use for the project repository URL."
                             :name "URL"}
           "--project-url" {:kind :single
                            :help "The value to use for the project web URL."
                            :name "URL"}
           "--type" {:kind    :single
                     :help    `The type of project. The valid types are 'exe' for
                              an executable, 'nat' for a native library and 'src'
                              for a Janet library.`
                     :value   type-value
                     :default "src"}
           :dir {:kind     :single
                 :help     "The directory in which to create the project."
                 :value    dir-value
                 :required true}]
   :info {:about `Create a new Janet project in a given directory

                 The new subcommand creates the files for a new Janet project.
                 Unless run with the --auto option, the user will be prompted to
                 enter the details used to create the project.janet file.`}
   :help "Create a new project."
   :fn   cmd-fn})
