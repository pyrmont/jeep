(def- seps {:windows "\\" :mingw "\\" :cygwin "\\"})
(def- s (get seps (os/which) "/"))

# based on code from spork/declare-cc.janet
(defn- add-bat-shim [manifest bin-name &opt chmod-mode]
  (def binpath (string (dyn :syspath) s "bin"))
  (def bin-dest (string binpath s bin-name))
  (assert (= :file (os/stat bin-dest :mode)) "must call bundle/add-bin first")
  (def bat-name (string bin-name ".bat"))
  (def files (get manifest :files)) # guaranteed to be non-nil
  (def dest (string binpath s bat-name))
  (when (os/stat dest :mode)
    (errorf "collision at %s, file already exists" dest))
  (def bat (string "@echo off\r\n"
                   "goto #_undefined_# 2>NUL || title %COMSPEC% & janet \""
                   bin-dest
                   "\" %*"))
  (spit dest bat)
  (def absdest (os/realpath dest))
  (array/push files absdest)
  (when chmod-mode
    (os/chmod absdest chmod-mode))
  (print "add " absdest))

(defn install [manifest &]
  (def manpages (get-in manifest [:info :manpage] []))
  (os/mkdir (string (dyn :syspath) s "man"))
  (os/mkdir (string (dyn :syspath) s "man" s "man1"))
  (each mp manpages
    (bundle/add-file manifest mp))
  (def prefix (get-in manifest [:info :source :prefix]))
  (def srcs (get-in manifest [:info :source :files] []))
  (bundle/add-directory manifest prefix)
  (each src srcs
    (bundle/add manifest src (string prefix s src)))
  (def bins (get-in manifest [:info :executable] []))
  (each bin bins
    (def bin-name (last (string/split "/" bin)))
    (bundle/add-bin manifest bin bin-name)
    (if (index-of (os/which) [:mingw :windows])
      (add-bat-shim manifest bin-name)))
  (def bundle-ver (get-in manifest [:info :version]))
  (if (not= "DEVEL" bundle-ver)
    (put manifest :version bundle-ver)
    (do
      (def src (get manifest :local-source))
      (def [r w] (os/pipe))
      (def [ok? res] (protect (os/execute ["git" "-C" src "describe" "--always" "--dirty"] :px {:out w :err w})))
      (:close w)
      (put manifest
           :version
           (if ok?
             (string bundle-ver "-" (string/trim (ev/read r :all)))
             bundle-ver)))))
