(defn install [manifest &]
  (def seps {:windows "\\" :mingw "\\" :cygwin "\\"})
  (def s (get seps (os/which) "/"))
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
    (bundle/add-bin manifest bin))
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
