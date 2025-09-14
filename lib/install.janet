(import ../deps/spork/spork/pm)
(import ./util)

(defn- manifest-pm-extract
  [m]
  (or
    (get m :pm) # installed by pm, has extra info like git repo, etc.
    (table/to-struct
      (merge-into @{:type :file :url (get m :local-source)} (get m :info {}))))) # just a path on disk, native janet support

(defn- installed-lookup
  [bundle]
  (def {:url url
        :tag tag
        :type bundle-type} bundle)
  (def key [url tag bundle-type])
  (var result nil)
  (each d (bundle/list)
    (def m (bundle/manifest d))
    (when m
      (def pm (manifest-pm-extract m))
      (def check [(get pm :url) (get pm :tag) (get pm :type)])
      (when (= check key)
        (set result (get m :name))
        (break))))
  result)

(defn- bundle-name-to-bundle
  [bundle-name]
  (manifest-pm-extract (bundle/manifest bundle-name)))

(defn install
  # modified version of Spork's pm/pm-install function
  [id &named auto-remove force-update no-install replace?]
  (def bundle (pm/resolve-bundle id))
  (def installed-name (installed-lookup bundle))
  (when (and installed-name (not replace?) (not force-update))
    (eprintf "bundle %s is already installed, skipping" installed-name)
    (break))
  (def {:url url :type bundle-type :tag tag} bundle)
  (def bdir (pm/download-bundle url bundle-type tag))
  (def info (util/load-meta bdir))
  (when (nil? info)
    (errorf "bundle at %s does not include info.jdn file" url))
  (def info-name (get info :name))
  (def conflict? (bundle/installed? info-name))
  (when (and (not replace?) (not installed-name) conflict?)
    (def existing (bundle-name-to-bundle info-name))
    (eprintf "a conflicting bundle %v is already installed, skipping" info-name)
    (eprintf "  existing bundle: %.99M" existing)
    (eprintf "  skipped bundle:  %.99M" bundle)
    (break))
  (def deps (get info :dependencies []))
  (each d deps
    (install d :replace? replace? :force-update force-update :auto-remove true))
  (def config @{:pm bundle :installed-with "jeep" :auto-remove auto-remove})
  (unless no-install
    (if (and replace? conflict?)
      (bundle/replace info-name bdir :config config ;(kvs config))
      (bundle/install bdir :config config ;(kvs config)))))

(defn install-to
  [dest id &named force-update no-install auto-remove]
  (if (string? id)
    (error "id must be struct/table"))
  (util/mkdir dest)
  (def temp-dir "tmp")
  (def oldpath (dyn *syspath*))
  (def syspath (util/change-syspath temp-dir))
  (def binpath (string syspath util/sep "bin"))
  (def manpath (string syspath util/sep "man"))
  (defn copy-dep [name]
    (def man (bundle/manifest name))
    (each f (get man :files)
      (unless (or (string/has-prefix? binpath f)
                  (string/has-prefix? manpath f))
        (def d (string dest util/sep (string/replace (dyn *syspath*) "" f)))
        (util/copy f d)))
    (each d (get man :dependencies)
      (copy-dep (get man :name))))
  (defer (do
           (util/change-syspath oldpath)
           (util/rmrf temp-dir))
    (install id :force-update force-update :no-install no-install :auto-remove auto-remove)
    (copy-dep (get id :name))))
