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
  (assert (string? s) "expected string")
  (= 35 (first s)))

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
  (assert (string? s) "expected string")
  (array? (peg/match :s s)))

# Dependent functions

(defn add-in
  [ds k v]
  (def indent @"")
  (var prev-indent nil)
  (def ks (map describe k))
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
  (defn first-indent [ds s-indent]
    (def res @"")
    (each el (array/slice ds 1 -2)
      (if (val? el)
        (break))
      (if (eol? el)
        (buffer/clear res)
        (buffer/push res el)))
    (if (empty? res) (string s-indent) (string res)))
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
        (def k-indent (first-indent arr prev-indent))
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
            (buffer/push indent " ")
            (def v-indent (first-indent el indent))
            (if (has-vals? el)
              (array/insert el -2 eol v-indent (janet->string v v-indent))
              (array/insert el -2 (janet->string v v-indent)))
            (break))
          (error "intermediate key mapped to non-dictionary"))
        (set key? true)))
    (++ i)))

(defn rem-from
  [ds k v]
  (def ks (map describe k))
  (var ks-i 0)
  (var arr ds)
  (var i 0)
  (var dict? false)
  (var key? false)
  (var need-val? true)
  # helpers
  (defn val?
    [el]
    (and (not (comment? el))
         (not (whitespace? el))))
  (defn remove [ds v]
    (var found? false)
    (var i 1)
    (var key? false)
    (var need-val? false)
    (while (< i (dec (length ds)))
      (def el (get ds i))
      (cond
        (and (array? el)
             (or (= "{" (first el))
                 (= "@{" (first el))))
        (do
          (set key? true)
          (each e (array/slice el 1 -2)
            (cond
              (and need-val? (val? e))
              (do
                (if (= e v)
                  (set found? true))
                (break))
              (and key? (val? e))
              (do
                (if (= e ":name")
                  (set need-val? true))
                (set key? false))
              (and (not key?) (val? e))
              (set key? true))))
        (= v el)
        (set found? true))
      (when found?
        (array/remove ds i)
        (while (< i (dec (length ds)))
          (def el (get ds i))
          (if (val? el)
            (break)
            (array/remove ds i)))
        (break))
      (++ i)))
  # main loop
  (while (def el (get arr i))
    (cond
      (and (array? el)
           (or (= "{" (first el))
               (= "@{" (first el)))
           need-val?)
      (do
        (set need-val? false)
        (set arr el)
        (set i 0)
        (set dict? true)
        (set key? true))
      (= "}" el)
      (error "value missing")
      (and dict? key? (val? el))
      (do
        (when (= (get ks ks-i) el)
          (set need-val? true)
          (++ ks-i))
        (set key? false))
      (and dict? (not key?) (val? el))
      (if need-val?
        (if (= (length ks) ks-i)
          (do
            (remove el v)
            (break))
          (error "intermediate key mapped to non-dictionary"))
        (set key? true)))
    (++ i)))
