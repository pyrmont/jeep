(import ../info)
(import ../util)

(def- helps
  {:autotag
   `Automatically add to each dep the tag associated with the current commit.`
   :vendor
   `Operate on the deps under the :vendored keyword.`
   :add-deps
   `Deps to add. Each dep can be a URL or JDN struct/table with a :url key.`
   :add-about
   `Adds dependency information to the bundle's info file.`
   :add-help
   `Add dependencies to the current bundle.`
   :rem-deps
   `Deps to remove. Each dep can be a name or URL.`
   :rem-about
   `Removes dependency information from the bundle's info file.`
   :rem-help
   `Remove dependencies from the current bundle.`
   :tidy-about
   `Sorts the bundle's dependencies by name.`
   :tidy-help
   `Sort the dependencies in the current bundle.`
   :edit-dep
   `Dep to edit. The dep can be a name or URL.`
   :edit-data
   `Keys and values to set on the dep. A value of nil removes the key.`
   :edit-about
   `Edits dependency information in the bundle's info file.`
   :edit-help
   `Edit a dependency in the current bundle.`
   :about
   `Adds, edits or removes dependency information in the bundle's info file.`
   :help
   `Add, edit or remove dependency information in the current bundle.`})

(def- add-config
  {:rules [:deps {:splat? true
                  :req?   true
                  :help   (helps :add-deps)}
           "--autotag" {:kind  :flag
                        :short "a"
                        :help  (helps :autotag)}
           "----"]
   :info {:about (helps :add-about)}
   :help (helps :add-help)})

(def- rem-config
  {:rules [:deps {:splat? true
                  :req?   true
                  :help   (helps :rem-deps)}
           "----"]
   :info {:about (helps :rem-about)}
   :help (helps :rem-help)})

(def- tidy-config
  {:rules ["----"]
   :info {:about (helps :tidy-about)}
   :help (helps :tidy-help)})

(def- edit-config
  {:rules [:dep {:req? true
                 :help (helps :edit-dep)}
           :data {:splat? true
                  :help   (helps :edit-data)}
           "--autotag" {:kind  :flag
                        :short "a"
                        :help  (helps :autotag)}
           "----"]
   :info {:about (helps :edit-about)}
   :help (helps :edit-help)})

(def config {:rules ["--vendor" {:kind  :flag
                                 :short "v"
                                 :help  (helps :vendor)}
                     "----"]
             :subs ["add" add-config
                    "edit" edit-config
                    "rem" rem-config
                    "tidy" tidy-config]
             :info {:about (helps :about)}
             :help (helps :help)})

(def- peg '(* :w+ "://"))
(var- changed? false)

(defn- to-dirname
  [url]
  (def b @"")
  (var i 0)
  (while (def c (get url i))
    (def us (chr "_"))
    (buffer/push b
                 (case c
                   (chr ":") us
                   (chr "/") us
                   (chr "~") us
                   (chr "?") us
                   c))
    (++ i))
  (string b))

(defn- fetch-repo
  [url]
  (def tmp (util/tmp-dir))
  (def dir (string tmp util/sep (to-dirname url)))
  (unless (os/mkdir dir)
    (break dir))
  (util/exec :git nil "clone" "--depth" "1" url dir)
  dir)

(defn- fetch-name
  [url]
  (def dir (fetch-repo url))
  (get (util/load-meta dir) :name))

(defn- fetch-tag
  [url]
  (if (nil? url) (break))
  (def dir (fetch-repo url))
  (def [r w] (os/pipe))
  (util/exec :git {:out w} "-C" dir "rev-parse" "HEAD")
  (:close w)
  (string/trim (ev/read r :all)))

(defn- bundle-from-url
  [listed url]
  (var res nil)
  (each d listed
    (when (and (dictionary? d)
               (= url (get d :url)))
      (set res d)
      (break)))
  (if (nil? res)
    (error (string "no dependency with URL " url))
    res))

(defn- to-url
  [s]
  (if (peg/match peg s) s (string "https://" s)))

(defn- name-index
  [listed name]
  (find-index
    (fn :finder [curr]
      (if (dictionary? curr)
        (= name (get curr :name))
        (= name curr)))
    listed))

(defn- add-deps
  [jdn meta group deps &opt autotag?]
  (def listed (get-in meta group []))
  (def to-add @[])
  (each d-str deps
    (def [ok? res] (protect (parse d-str)))
    (def d (if (and ok? (dictionary? res)) res d-str))
    (cond
      (dictionary? d)
      (do
        (assertf (get d :name) "dependency %n requires :name" d)
        (assertf (get d :url) "dependency %n requires :url" d)
        (def tag (if autotag? (fetch-tag (get d :url))))
        (array/push to-add (struct :tag tag ;(kvs d))))
      (util/url? d)
      (do
        (def url (to-url d))
        (def name (fetch-name url))
        (assertf name "dependency %s is missing info.jdn file with :name key" url)
        (array/push to-add {:name name :url url :tag (if autotag? (fetch-tag url))}))
      # default
      (errorf "dependency %s must be a URL or a struct/table with a :url key" d))
    (def new (array/peek to-add))
    (def new-name (if (dictionary? new) (get new :name) new))
    (assertf (string? new-name) "dependency %n requires :name to be a string" new)
    (when (name-index listed new-name)
      (print "skipping " new-name ", use 'jeep dep edit' to edit existing dependencies")
      (array/pop to-add)))
  (var result jdn)
  (each d to-add
    (set changed? true)
    (print "adding " (if (dictionary? d) (get d :name) d) "...")
    (set result (info/append result group [d])))
  result)

(defn- rem-deps
  [jdn meta group deps]
  (def listed (get-in meta group []))
  (if (empty? listed) (break jdn))
  (def to-rem @[])
  (each d deps
    (cond
      (util/url? d)
      (array/push to-rem (get (bundle-from-url listed (to-url d)) :name))
      # default
      (array/push to-rem d)))
  (def positions @{})
  (each d to-rem
    (set changed? true)
    (print "removing " (if (dictionary? d) (get d :name) d) "...")
    (eachp [i x] listed
      (when (or (= x d) (= (get x :name) d))
        (put positions i true))))
  (var result jdn)
  (var i (dec (length listed)))
  (while (>= i 0)
    (when (get positions i)
      (set result (info/remove result [;group i])))
    (-- i))
  result)

(defn- tidy-deps
  [jdn meta group]
  (unless (has-key? meta (first group))
    (break jdn))
  (def before (info/render jdn))
  (def result
    (info/sort jdn group
               :by (fn :namer [d] (if (dictionary? d) (get d :name) d))))
  (unless (= before (info/render result))
    (set changed? true)
    (print "tidying..."))
  result)

(defn- pair-value
  [pairs k]
  (var res nil)
  (each [pk pv] pairs
    (when (= k pk)
      (set res pv)
      (break)))
  res)

(defn- edit-dep
  [jdn meta group dep data &opt autotag?]
  (def listed (get-in meta group []))
  (def pairs (util/to-pairs data))
  (assert (or autotag? (not (empty? pairs)))
          "must provide at least one key and value or set --autotag")
  (def name
    (if (util/url? dep)
      (get (bundle-from-url listed (to-url dep)) :name)
      dep))
  (def pos (name-index listed name))
  (assertf pos "dependency %s is not listed, add it first" name)
  (def curr (get listed pos))
  # a dependency is found by its name, so an entry cannot lose it and two
  # entries cannot share it; both are checked before any pair is applied
  (each [k v] pairs
    (when (= :name k)
      (assert (not (nil? v)) "cannot remove the :name key")
      (assert (string? v) "the :name key must be a string")
      (def other (name-index listed v))
      (assertf (or (nil? other) (= pos other))
               "dependency %s is already listed" v)))
  # the tag is resolved from the new URL if one is being set
  (when autotag?
    (def url (or (pair-value pairs :url)
                 (if (dictionary? curr) (get curr :url))))
    (assertf url "cannot autotag dependency %s without :url set" name)
    (array/push pairs [:tag (fetch-tag url)]))
  (sort-by (fn :keyer [[k]] k) pairs)
  (def before (info/render jdn))
  (var result jdn)
  (if (dictionary? curr)
    (each [k v] pairs
      (if (nil? v)
        (when (has-key? curr k)
          (set result (info/remove result [;group pos k])))
        (set result (info/put result [;group pos k] v))))
    # an entry listed as a bare name is converted into a struct
    (do
      (def promoted @{:name name})
      (each [k v] pairs
        (put promoted k v))
      (set result (info/put result [;group pos] (table/to-struct promoted)))))
  (unless (= before (info/render result))
    (set changed? true)
    (print "editing " name "..."))
  result)

(defn run
  [args &opt jeep-config]
  jeep-config # TODO: Add support for configuring via existing file
  (set changed? false)
  (def opts (get-in args [:sub :opts] {}))
  (def sub (get-in args [:sub :sub] {}))
  (def cmd (get sub :cmd))
  (def params (get sub :params {}))
  (def autotag? (get-in sub [:opts "autotag"]))
  (def group (if (get opts "vendor") [:vendored] [:dependencies]))
  (def info (util/load-info))
  (assert info "no info.jdn file found")
  (def [ok? parsed]
    (protect
      (do
        (def jdn (info/parse info))
        [jdn (info/value jdn)])))
  (assert ok? "info.jdn could not be parsed")
  (def [jdn meta] parsed)
  (assert (get meta :name) "info.jdn file must contain the :name key")
  (def cwd (os/cwd))
  (def edited
    (case cmd
      "add"
      (defer
        (util/cleanup cwd)
        (add-deps jdn meta group (get params :deps []) autotag?))
      "edit"
      (defer
        (util/cleanup cwd)
        (edit-dep jdn meta group (get params :dep) (get params :data []) autotag?))
      "rem"
      (rem-deps jdn meta group (get params :deps []))
      "tidy"
      (tidy-deps jdn meta group)
      # default
      (errorf "unknown subcommand %n" cmd)))
  (util/save-info (info/render edited))
  (if changed?
    (print "Dependencies changed.")
    (print "No dependencies changed.")))
