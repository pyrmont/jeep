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

(def- eol "\n")

# Independent functions

(defn- comment?
  [s]
  (if (string? s)
    (= 35 (first s))))

(defn- dict?
  [v]
  (and (array? v)
       (or (= "{" (first v))
           (= "@{" (first v)))))

(defn- eol?
  [s]
  (or (= eol s) (= "\r\n" s)))

(defn- ind?
  [v]
  (and (array? v)
       (or (= "[" (first v))
           (= "@[" (first v)))))

(defn- janet->string
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
    (each [k v] (sort (pairs dict))
      (if (and (= :name k) (string? v))
        (if first?
          (do
            (set first? false)
            (buffer/push b ":name \"" v "\""))
          (do
            (def rest (buffer/slice b 1))
            (buffer/popn b (dec (length b)))
            (buffer/push b ":name \"" v "\"" eol k-indent rest)))
        (do
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
          (buffer/push b (janet->string v v-indent)))))
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

(defn- whitespace?
  [s]
  (if (string? s)
    (string/check-set " \t\n\r" s)))

# Dependent functions

(var- last-line (fn :last-line [b el]))

(defn- add-space
  [b el]
  (cond
    (comment? el)
    (buffer/clear b)
    (= eol el)
    (buffer/clear b)
    (whitespace? el)
    (buffer/push b el)
    (array? el)
    (last-line b el)
    # default
    (buffer/push b (string/repeat " " (length el)))))

(defn- squish-space
  [coll]
  (var i 1)
  (while (def el (get coll i))
    (unless (whitespace? el)
      (break))
    (array/remove coll i)))

(set last-line (fn :last-line
  [b arr]
  (each el arr (add-space b el))))

(defn- val?
  [v]
  (or (array? v)
      (and (not (comment? v))
           (not (whitespace? v))
           (not (string/check-set "{}[]" v)))))

(defn- find-in
  [ds kl &opt expect]
  # 'kl' means keylist
  (var res @[])
  (var linenum 1)
  (var kl-i 0)
  (var coll ds)
  (var coll-i 0)
  (var coll-type nil)
  (var el-key? false)
  (var el-val? false)
  (var el-i nil)
  (var next-coll expect)
  (while (def el (get coll coll-i))
    (cond
      (comment? el)
      (++ linenum)
      (whitespace? el)
      (++ linenum)
      next-coll
      (cond
        (= :dict next-coll)
        (if (dict? el)
          (do
            (set next-coll nil)
            (array/push res coll-i)
            (if (zero? (length kl))
              (break))
            (set coll el)
            (set coll-i 0)
            (set coll-type :dict)
            (set el-key? true)
            (set el-val? false)
            (set el-i nil))
          (if (= 0 kl-i)
            (errorf "parse error on info.jdn, line %d: expected struct/table at top level" linenum)
            (errorf "parse error on info.jdn, line %d: expected struct/table to be mapped to keys %n" linenum (array/slice kl 0 kl-i))))
        (= :ind next-coll)
        (if (ind? el)
          (do
            (set next-coll nil)
            (array/push res coll-i)
            (if (zero? (length kl))
              (break))
            (set coll el)
            (set coll-i 0)
            (set coll-type :ind)
            (set el-key? false)
            (set el-val? false)
            (set el-i 0))
          (if (= 0 kl-i)
            (errorf "parse error on info.jdn, line %d: expected struct/table at top level of info.jdn file")
            (errorf "parse error on info.jdn, line %d: expected struct/table to be mapped to keys %n" (array/slice kl 0 kl-i))))
        # default
        (errorf "parse error on info.jdn, line %d: error parsing info.jdn"))
      el-val?
      (if (val? el)
        (if (= (length kl) kl-i)
          (do
            (array/push res coll-i)
            (break))
          (if (array? el)
            (do
              (array/push res coll-i)
              (set coll el)
              (set coll-i 0) # this will become 1 at iteration end
              (if (dict? el)
                (do
                  (set el-key? true)
                  (set el-val? false)
                  (set el-i nil))
                (do
                  (set el-key? false)
                  (set el-val? false)
                  (set el-i 0))))
            (break)))
        (errorf "parse error on info.jdn, line %d: struct/table must have even number of key-value pairs"))
      (= "}" el)
      (break)
      (= "]" el)
      (break)
      el-key?
      (if (val? el)
        (if (= el (describe (get kl kl-i)))
          (do
            (set el-key? false)
            (set el-val? true)
            (++ kl-i))
          (do
            (set el-key? false)
            (set el-val? false)))
        (error "parse error on info.jdn, line %d: expected key"))
      el-i
      (if (= el-i (get kl kl-i))
        (if (= (length kl) (++ kl-i))
          (do
            (array/push res coll-i)
            (break))
          (if (array? el)
            (do
              (array/push res coll-i)
              (set coll el)
              (set coll-i 0)
              (set el-i nil))
            (break)))
        (++ el-i))
      # default
      (set el-key? true))
    (++ coll-i))
  (set linenum 0)
  res)

(defn- find-nl
  [coll begin end]
  (var i begin)
  (var f (if (< end begin) dec inc))
  (while (not= i end)
    (if (= eol (get coll i))
      (break))
    (set i (f i)))
  (if (= i end)
    begin
    i))

# Public API

(defn jdn-arr->jdn-str
  [jdn]
  (if (string? jdn)
    (break jdn))
  (def b @"")
  (each el jdn
    (if (string? el)
      (buffer/push b el)
      (buffer/push b (jdn-arr->jdn-str el))))
  (string b))

(defn jdn-str->jdn-arr
  [s]
  (peg/match peg s))

(defn add-to
  [ds kl v]
  (def trail (find-in ds kl :dict))
  (def indent @"")
  (var coll ds)
  (each i trail
    (var j 0)
    (while (< j i)
      (add-space indent (get coll j))
      (++ j))
    (set coll (get coll i)))
  (var i (dec (length trail)))
  (if (= (length kl) i)
    (cond
      (dict? coll)
      (do
        (assertf (dictionary? v) "key path '%n' resolves to '%n' but expected struct/table" kl coll)
        (buffer/push indent (string/repeat " " (length (first coll))))
        (eachp [el-k el-v] v
          (array/pop coll)
          (def k-str (describe el-k))
          (def v-arr
            (-> (janet->string el-v (string indent (string/repeat " " (length k-str)) " "))
                (jdn-str->jdn-arr)
                (array/pop)))
          (if (not (one? (length coll)))
            (array/push coll eol (string indent)))
          (array/push coll k-str " " v-arr "}")))
      (ind? coll)
      (do
        (assertf (indexed? v) "key path '%n' resolves to '%n' but expected array/tuple" kl coll)
        (buffer/push indent (string/repeat " " (length (first coll))))
        (each el v
          (array/pop coll)
          (def el-arr
            (-> (janet->string el (string indent))
                (jdn-str->jdn-arr)
                (array/pop)))
          (if (not (one? (length coll)))
            (array/push coll eol (string indent)))
          (array/push coll el-arr "]")))
      # default
      (errorf "key path '%n' resolves to '%n' but expected collection" kl coll))
    (while (< i (length kl))
      (def k (get kl i))
      (assertf (array? coll) "key path '%n' resolves to '%n' but expected collection" kl coll)
      (buffer/push indent (string/repeat " " (length (first coll))))
      (array/pop coll)
      (assertf (bytes? k) "invalid key '%n', must be keyword/string" k)
      (def k-str (describe k))
      (def v-arr
        (if (= (length kl) (inc i))
          (-> (janet->string v (string indent (length k-str) " "))
              (jdn-str->jdn-arr)
              (array/pop))
          @["{" "}"]))
      (if (not (one? (length coll)))
        (array/push coll eol (string indent)))
      (array/push coll k-str " " v-arr "}")
      (set coll v-arr)
      (buffer/push indent (string/repeat " " (length k-str)))
      (++ i)))
  ds)

(defn rem-from
  [ds kl &named where]
  (def trail (find-in ds kl :dict))
  (assertf (= (length kl) (dec (length trail))) "no match for key path '%n' in metadata" kl)
  (def parent-trail (array/slice trail 0 (if where -1 -2)))
  (def coll (get-in ds parent-trail))
  (assertf (array? coll) "key path '%n' resolves to '%n' but expected collection" kl coll)
  (if where
    (do
      (def pred (if (function? where) where (partial deep= where)))
      (var i 0)
      (if (ind? coll)
        (while (def el (get coll i))
          (if (and (val? el)
                   (pred (parse (jdn-arr->jdn-str el))))
            (do
              (array/remove coll i)
              (if (whitespace? (get coll (- i 1) "0"))
                (array/remove coll (- i 1)))
              (if (whitespace? (get coll (- i 2) "0"))
                (array/remove coll (- i 1))))
            (++ i)))
        (error ":where not implemented for structs/tables")))
    (do
      (var val-i (last trail))
      (if (dict? coll)
        (do
          (var key-i (dec val-i))
          (while (> key-i 0)
            (unless (whitespace? (get coll key-i))
              (break))
            (-- key-i))
          (assert (not= key-i 0) "impossible")
          (array/remove coll key-i (inc (- val-i key-i)))
          (if (whitespace? (get coll (- key-i 1) "0"))
            (array/remove coll (- key-i 1)))
          (if (whitespace? (get coll (- key-i 2) "0"))
            (array/remove coll (- key-i 1))))
        (error "not implemented for arrays/tuples"))))
  (squish-space coll)
  ds)

(defn- assoc
  [coll add indent]
  (assert add "must provide :add argument")
  (buffer/push indent )
  (each [k v] (partition 2 add)
    (def trail (find-in coll [k]))
    (assert (< (length trail) 2) "unexpected length")
    (if (def i (first trail))
      (put coll i (-> (janet->string v indent)
                      (jdn-str->jdn-arr)
                      (array/pop)))
      (do
        (def dcl (array/pop coll))
        (unless (one? (length coll))
          (array/push coll eol)
          (array/push coll (string indent)))
        (array/push coll (describe k))
        (array/push coll " ")
        (array/push coll (-> (janet->string v indent)
                             (jdn-str->jdn-arr)
                             (array/pop)))
        (array/push coll dcl)))))

(defn- swap
  [coll i to indent]
  (cond
    (or (array? to) (table? to))
    (buffer/push indent "  ")
    (or (struct? to) (tuple? to))
    (buffer/push indent " "))
  (put coll i (-> (janet->string to indent)
                  (jdn-str->jdn-arr)
                  (array/pop))))

(defn upd-in
  [ds kl &named where add to]
  (assert (not (and (nil? add) (nil? to))) "must provide :add or :to argument")
  (assert (or (nil? add) (nil? to)) "cannot provide both :add and :to arguments")
  (def trail (find-in ds kl :dict))
  (assertf (= (length kl) (dec (length trail))) "no match for key path '%n' in metadata" kl)
  (def indent @"")
  (var coll ds)
  (each i trail
    (var j 0)
    (while (< j i)
      (add-space indent (get coll j))
      (++ j))
    (set coll (get coll i)))
  (def pred (unless (nil? where)
              (if (function? where)
                where
                (partial deep= where))))
  (if pred
    (do
      (assertf (ind? coll) ":where argument requires array/tuple, found %n" coll)
      (var i 0)
      (while (def el (get coll i))
        (when (val? el)
          (def v (parse (jdn-arr->jdn-str el)))
          (when (pred v)
            (if (nil? to)
              (do
                (assertf (dict? el) "expected struct/table, found %n" el)
                (assoc el add (buffer indent (string/repeat " " (+ (length (get coll 0))
                                                                   (length (get el 0)))))))
              (swap coll i to indent))))
        (++ i)))
    (error "not implemented for structs/tables"))
  ds)
