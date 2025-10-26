(defn install [manifest &]
  (def seps {:windows "\\" :mingw "\\" :cygwin "\\"})
  (def s (get seps (os/which) "/"))
  (def srcs (get-in manifest [:info :source :files] []))
  (each src srcs
    (bundle/add manifest src (last (string/split "/" src)))))
