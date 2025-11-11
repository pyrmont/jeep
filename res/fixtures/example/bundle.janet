(defn install [manifest &]
  (def seps {:windows "\\" :mingw "\\" :cygwin "\\"})
  (def s (get seps (os/which) "/"))
  (def libs (get-in manifest [:info :artifacts :libraries] []))
  (each lib libs
    (each src (get lib :paths)
      (bundle/add manifest src (last (string/split "/" src))))))
