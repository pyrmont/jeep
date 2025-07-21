(use ../deps/testament)

(import ../lib/jdn)

(deftest is-comment
  (is (== true (jdn/comment? "# this is a comment"))))

(deftest no-comment
  (is (== false (jdn/comment? "this is not a comment"))))

(deftest is-whitespace
  (is (== true (jdn/whitespace? " ")))
  (is (== true (jdn/whitespace? "\t")))
  (is (== true (jdn/whitespace? "\n"))))

(deftest not-whitespace
  (is (== false (jdn/whitespace? "a"))))

(run-tests!)
