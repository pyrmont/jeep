(import ./new :as cmd/new)

# Help strings
(def- helps
  {:about
   `Enhances the current bundle into a modern bundle.`
   :help
   `Enhance the current bundle into a modern bundle.`})

(def- extra
  {:info {:about (helps :about)}
   :help (helps :help)})

(def config
  (do
    (def res (merge cmd/new/config extra))
    (def rules (array/slice (get res :rules) 2))
    (put res :rules rules)
    res))

(defn- parse-project
  []
  (def pf (parse-all (slurp "project.janet")))
  (def project @{})
  (each f pf
    (def op (first f))
    (when (or (= 'declare-project op)
              (= 'declare-binscript op)
              (= 'declare-source op))
      (def k (keyword/slice op 8))
      (if (= :project k)
        (put project k (struct ;(slice f 1)))
        (do
          (unless (has-key? project k)
            (put project k @[]))
          (array/push (get project k) (struct ;(slice f 1)))))))
  project)

(defn- setup-defaults
  [project]
  (def res @{})
  (def meta (get project :project))
  (def ks [:name :description :version :author :license :url :repo
           :dependencies])
  (each k ks
    (put res k (get meta k)))
  # libraries
  (def libs (seq [s :in (get project :source [])]
              {:prefix (get s :prefix)
               :paths (get s :source)}))
  # scripts
  (def scps (seq [b :in (get project :binscript [])]
              {:path (get b :main)
               # NOTE Is this needed in modern bundles?
               # :syspath? (get b :hardcode-syspath)
               }))
  (put res :artifacts {:executables []
                       :libraries (tuple/slice libs 0)
                       :manpages []
                       :natives []
                       :scripts (tuple/slice scps 0)})
  res)

(defn run
  [args]
  (def opts (get-in args [:sub :opts] {}))
  (def project (parse-project))
  (def defaults (setup-defaults project))
  (def params {:name (get defaults :name)})
  (def backups {"project.janet" true})
  (if (cmd/new/create-bundle opts params "." defaults backups)
    (print "Bundle enhanced.")
    (print "Command failed.")))
