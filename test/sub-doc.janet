(use testament)
(use ../test-utils)


(deftest doc-echo
  (def msg ````# example API

           ## example

           [foo](#foo)

           ## foo

           **function**  | [source][1]

           ```janet
           (foo)
           ```

           Returns true

           [1]: example.janet#L1````)
  (def expect {:err "" :out (string msg "\n\n\n") :status 0})
  (def actual (run-cmd "doc" "-e" "-p" "fixtures/doc/project.janet"))
  (is (== expect actual)))


(run-tests!)
