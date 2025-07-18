(def- peg
  ~{:main (* :content -1)
    :content (any (+ :comment :eol :sp :form))
    :comment '(* "#" (any (if-not (+ "\n" -1) 1)) (? "\n"))
    :eol '(+ "\n" (* "\r\n"))
    :sp '(some (set " \0\f\t\v"))
    :form (+ :compound :non-compound)
    :compound (group (* ':open :content ':close))
    :open (* (? "@") (set "([{"))
    :close (set ")]}")
    :non-compound '(+ :keyword :string :non-string)
    :keyword (* ":" (+ :string :non-string))
    :string (* (? "@") (+ :dq-string :ls-string))
    :dq-string (* `"` (any (+ (* `\` 1) (if-not `"` 1))) `"`)
    :ls-string {:main (drop (* :open (any (if-not :close 1)) :close))
                :open (<- (some "`") :n)
                :close (cmt (* (not (> -1 "`")) (backref :n) (<- (backmatch :n))) ,=)}
    :non-string (some (if-not (+ :s :open :close) 1))})

(def eol "\n")

# Independent functions

(defn comment?
  [s]
  (and (string? s) (= "#" (first s))))

(defn eol?
  [s]
  (or (= "\n" s) (= "\r\n" s)))

(defn janet->string
  [j indent]
  (def t (type j))
  (assert (not (or (= :function t)
                   (= :cfunction t)
                   (= :abstract t))) "cannot print functions or abstract types")
  (def b @"")
  (defn dict->string [dict open close]
    (var first? true)
    (def k-indent (string indent (string/repeat " " (length open))))
    (buffer/push b open)
    (each [k v] (pairs dict)
      (if first?
        (set first? false)
        (buffer/push b eol k-indent))
      (buffer/push b (janet->string k k-indent))
      (if (bytes? k)
        (buffer/push b " ")
        (buffer/push b eol k-indent))
      (def extra (string/repeat " " (cond (keyword? k) (+ 2 (length k))
                                          (string? k) (+ 2 (length k))
                                          (symbol? k) (inc (length k))
                                          0)))
      (def v-indent (string k-indent extra))
      (buffer/push b (janet->string v v-indent)))
    (buffer/push b close))
  (defn ind->string [ind open close]
    (var first? true)
    (def el-indent (string indent (string/repeat " " (length open))))
    (buffer/push b open)
    (each el ind
      (if first?
        (set first? false)
        (buffer/push b eol el-indent))
      (buffer/push b (janet->string el el-indent)))
    (buffer/push b close))
  (case t
    :tuple
    (ind->string j "[" "]")
    :array
    (ind->string j "@[" "]")
    :struct
    (dict->string j "{" "}")
    :table
    (dict->string j "@{" "}")
    # default
    (buffer/push b (describe j)))
  (string b))

(defn jdn-arr->jdn-str
  [jdn]
  (def b @"")
  (each el jdn
    (if (string? el)
      (buffer/push b el)
      (buffer/push b (jdn-arr->jdn-str el))))
  b)

(defn jdn-str->jdn-arr
  [s]
  (peg/match peg s))

(defn whitespace?
  [s]
  (and (string? s) (peg/match :s s)))

# Dependent functions

(defn add-in
  [ds k v]
  (def indent @"")
  (var prev-indent nil)
  (def ks (map describe (if (indexed? k) k [k])))
  (pp ks)
  (var ks-i 0)
  (var arr ds)
  (var i 0)
  (var dict? false)
  (var key? false)
  (var need-val? true)
  # helpers
  (defn- val?
    [el]
    (and (not (comment? el))
         (not (whitespace? el))))
  (defn first-indent [ds]
    (def res @"")
    (each el (array/slice ds 1 -2)
      (if (val? el)
        (break))
      (if (eol? el)
        (buffer/clear res)
        (buffer/push res el)))
    (if (empty? res) prev-indent (string res)))
  (defn has-vals? [ds]
    (var res false)
    (each el (array/slice ds 1 -2)
      (when (val? el)
        (set res true)
        (break)))
    res)
  # main loop
  (while (def el (get arr i))
    (cond
      (and (array? el)
           (or (= "{" (first el))
               (= "@{" (first el)))
           need-val?)
      (do
        (set need-val? false)
        (def extra (length (first el)))
        (buffer/push indent (string/repeat " " extra))
        (set prev-indent (string indent))
        (set arr el)
        (set i 0)
        (set dict? true)
        (set key? true))
      (= "}" el)
      (do
        (def curr-k (get ks ks-i))
        (def j
          (if (< (++ ks-i) (length ks))
            (table/to-struct (put-in @{} (array/slice ks ks-i) [v]))
            [v]))
        (def k-indent (first-indent arr))
        (def v-indent (string k-indent (string/repeat " " (inc (length curr-k)))))
        (def curr-v (jdn-str->jdn-arr (janet->string j v-indent)))
        (if (has-vals? arr)
          (array/insert arr -2 eol k-indent curr-k " " ;curr-v)
          (array/insert arr -2 curr-k " " ;curr-v))
        (break))
      (whitespace? el)
      (if (eol? el)
        (buffer/clear indent)
        (buffer/push indent el))
      (and dict? key? (val? el))
      (do
        (when (= (get ks ks-i) el)
          (set need-val? true)
          (++ ks-i)
          (buffer/push indent (string/repeat " " (length el))))
        (set key? false))
      (and dict? (not key?) (val? el))
      (if need-val?
        (if (= (length ks) ks-i)
          (do
            (def v-indent (first-indent el))
            (if (has-vals? el)
              (array/insert el -2 eol v-indent (janet->string v v-indent))
              (array/insert el -2 (janet->string v v-indent)))
            (break))
          (error "intermediate key mapped to non-dictionary"))
        (set key? true)))
    (++ i)))

# (def s
#   ```
#   # this is a comment
#   {:name "my-module"
#    :dependencies ["some-dep"]
#    :foo 5
#     }
#   ```)
#
# (def jdn (jdn-str->jdn-arr s))
#
# (print s)
# (print)
# (pp jdn)
# (print)
# (add-dep jdn {:git "https://github.com/pyrmont/testament" :name "testament"} ":dependencies")
# (print (jdn-arr->jdn-str jdn))
