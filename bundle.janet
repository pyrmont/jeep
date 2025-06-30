(defn install [manifest &]
  (def seps {:windows "\\" :mingw "\\" :cygwin "\\"})
  (def s (get seps (os/which) "/"))
  (def prefix (get-in manifest [:info :source :prefix]))
  (def srcs (get-in manifest [:info :source :files] []))
  (bundle/add-directory manifest prefix)
  (each src srcs
    (bundle/add manifest src (string prefix s src)))
  (def bins (get-in manifest [:info :executable] []))
  (each bin bins
    (bundle/add-bin manifest bin)))
