(defn install [manifest &]
  (def libs (get-in manifest [:info :artifacts :libraries] []))
  (each lib libs
    (each src (get lib :paths)
      (bundle/add manifest src (last (string/split "/" src))))))
