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

(defn dict?
  [v]
  (and (array? v)
       (or (= "{" (first v))
           (= "@{" (first v)))))

(defn eol?
  [s]
  (or (= "\n" s) (= "\r\n" s)))

(defn ind?
  [v]
  (and (array? v)
       (or (= "[" (first v))
           (= "@[" (first v)))))

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
  (string b))

(defn jdn-str->jdn-arr
  [s]
  (peg/match peg s))

(defn whitespace?
  [s]
  (assert (string? s) "expected string")
  (array? (peg/match :s s)))

# Dependent functions

(defn- val?
  [v]
  (or (array? v)
      (and (not (comment? v))
           (not (whitespace? v))
           (not (= "}" v)))))

(defn add-to
  [ds kl v]
  (def indent @"")
  (var prev-indent nil)
  (def ks (map describe kl))
  (var ks-i 0)
  (var arr ds)
  (var arr-i 0)
  (var need-dict? true)
  (var need-key? false)
  # helpers
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
  (while (def el (get arr arr-i))
    (when (and need-dict? (val? el) (not (dict? el)))
      (def k (get ks (dec ks-i)))
      (error (string "expected dictionary collection to be mapped to key " k)))
    (when (and (= (length ks) ks-i) (val? el) (not (ind? el)))
      (def k (get ks (dec ks-i)))
      (error (string "expected indexed collection to be mapped to key " k)))
    (if (string? el)
      (cond
        # --
        (comment? el)
        nil # ignore comments
        # --
        (whitespace? el)
        (if (eol? el)
          (buffer/clear indent)
          (buffer/push indent el))
        # --
        (= "}" el)
        (do
          (def curr-k (get ks ks-i))
          (def j
            (if (< (++ ks-i) (length ks))
              (table/to-struct (put-in @{} (array/slice kl ks-i) [v]))
              [v]))
          (def k-indent (first-indent arr prev-indent))
          (def v-indent (string k-indent (string/repeat " " (inc (length curr-k)))))
          (def curr-v (jdn-str->jdn-arr (janet->string j v-indent)))
          (if (has-vals? arr)
            (array/insert arr -2 eol k-indent curr-k " " ;curr-v)
            (array/insert arr -2 curr-k " " ;curr-v))
          (break))
        # --
        need-key?
        (do
          (set need-key? false)
          (when (= (get ks ks-i) el)
            (def curr-k (get ks ks-i))
            (buffer/push indent (string/repeat " " (length curr-k)))
            (++ ks-i)
            (set need-dict? (not= (length ks) ks-i))))
        # --
        (set need-key? true))
      (cond
        # --
        (and need-dict? (dict? el))
        (do
          (def delim-len (length (first el)))
          (buffer/push indent (string/repeat " " delim-len))
          (set prev-indent (string indent))
          (set arr el)
          (set arr-i 0)
          (set need-key? true)
          (set need-dict? false))
        # --
        (and (= (length ks) ks-i) (ind? el))
        (do
          (buffer/push indent " ")
          (def v-indent (first-indent el indent))
          (if (has-vals? el)
            (array/insert el -2 eol v-indent (janet->string v v-indent))
            (array/insert el -2 (janet->string v v-indent)))
          (break))))
    (++ arr-i))
  # (print (jdn-arr->jdn-str ds))
  ds)

(defn rem-from
  [ds kl v]
  (def ks (map describe kl))
  (var ks-i 0)
  (var arr ds)
  (var arr-i 0)
  (var need-dict? true)
  (var need-key? false)
  # helpers
  (defn find-val [ind v]
    (var res nil)
    (var i 1)
    (while (def x (get ind i))
      (if (= x (describe v))
        (set res i)
        (when (dict? x)
          (var need-key? true)
          (var need-val? false)
          (each y (array/slice x 1 -2)
            (when (val? y)
              (when need-val?
                (if (= y (describe v))
                  (set res i))
                (break))
              (if (and need-key? (= ":name" y))
                (set need-val? true))
              (set need-key? (not need-key?))))))
      (if res
        (break))
      (++ i))
    res)
  # main loop
  (while (def el (get arr arr-i))
    (when (and need-dict? (val? el) (not (dict? el)))
      (def k (get ks (dec ks-i)))
      (error (string "expected dictionary collection to be mapped to key " k)))
    (when (and (= (length ks) ks-i) (val? el) (not (ind? el)))
      (def k (get ks (dec ks-i)))
      (error (string "expected indexed collection to be mapped to key " k)))
    (if (string? el)
      (cond
        # --
        (comment? el)
        nil # ignore comments
        # --
        (whitespace? el)
        nil # ignore whitespace
        # --
        (= "}" el)
        (error (string "key " (get ks ks-i)  " missing from dictionary collection"))
        # --
        need-key?
        (do
          (set need-key? false)
          (when (= (get ks ks-i) el)
            (++ ks-i)
            (set need-dict? (not= (length ks) ks-i))))
        # --
        (set need-key? true))
      (cond
        # --
        (and need-dict? (dict? el))
        (do
          (set arr el)
          (set arr-i 0)
          (set need-key? true)
          (set need-dict? false))
        # --
        (and (= (length ks) ks-i) (ind? el))
        (do
          (def end (find-val el v))
          (if (nil? end)
            (error (string (describe v) " not in indexed collection")))
          (var i (dec end))
          (while (def x (get el i))
            (when (or (= 1 i) (val? x))
              (def start (inc i))
              (array/remove el start (inc (- end start)))
              (break))
            (-- i))
          (break))))
    (++ arr-i))
  # (print (jdn-arr->jdn-str ds))
  ds)
