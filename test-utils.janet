(defn run-cmd [& args]
  (def cmd "./build/jeep")
  (def env {"JEEP_SUBCMDS" "" "TERM" (os/getenv "TERM") :out :pipe :err :pipe})
  (def proc (os/spawn [cmd ;args] :ep env))
  (def out (get proc :out))
  (def err (get proc :err))
  (def out-buf @"")
  (def err-buf @"")
  (var status 0)
  (ev/gather
    (:read out :all out-buf)
    (:read err :all err-buf)
    (set status (:wait proc)))
  {:err err-buf
   :out out-buf
   :status status})


