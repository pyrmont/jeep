(import ../deps/spork/spork/pm)
(import ./util)

(defn- manifest-pm-extract
  [m]
  (or
    (get m :pm) # installed by pm, has extra info like git repo, etc.
    (table/to-struct
      (merge-into @{:type :file :url (get m :local-source)} (get m :info {}))))) # just a path on disk, native janet support

(defn- name-lookup
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
  [id &named no-deps force-update no-install auto-remove]
  (def bundle (pm/resolve-bundle id))
  (def inst-name (name-lookup bundle))
  (when (and inst-name (not force-update))
    (eprintf "bundle %s is already installed, skipping" inst-name)
    (break))
  (def {:url url :type bundle-type :tag tag} bundle)
  (def bdir (pm/download-bundle url bundle-type tag))
  (def info (util/load-meta bdir))
  (when (nil? info)
    (errorf "bundle at %s does not include info.jdn file" url))
  (def info-name (get info :name))
  (when (and (not inst-name) (bundle/installed? info-name))
    (def existing (bundle-name-to-bundle info-name))
    (eprintf "a conflicting bundle %v is already installed, skipping" info-name)
    (eprintf "  existing bundle: %.99M" existing)
    (eprintf "  skipped bundle:  %.99M" bundle)
    (break))
  (def deps (get info :dependencies []))
  (each d deps
    (install d :force-update force-update :auto-remove true))
  (def config @{:pm bundle :installed-with "jeep" :auto-remove auto-remove})
  (unless no-install
    (if (and inst-name (bundle/installed? inst-name))
      (bundle/replace inst-name bdir :config config ;(kvs config))
      (bundle/install bdir :config config ;(kvs config)))))

# (defn manifest
#   [path]
#   (def abspath (os/realpath path))
#   (def bundle (pm/resolve-bundle (string "file::" abspath)))
#   (def info (util/load-meta abspath))
#   (def [ok module] (protect (require "/bundle")))
#   {:name (get info :name)
#    :dependencies (get info :dependencies)
#    :files @[]
#    :hooks (when ok (seq [[k v] :pairs module :when (symbol? k) :unless (get v :private)] (keyword k)))
#    :info info
#    :local-source abspath})
