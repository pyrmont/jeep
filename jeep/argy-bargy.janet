# Global values

(def- dir-sep "/")
(def- max-width 120)
(def- pad-inset 4)
(def- pad-right 6)

(var- cols nil)
(var- command "")
(var- errored? false)


# Utility functions

(defn- get-cols
  ```
  Get the columns in the terminal
  ```
  []
  (if (nil? cols)
    (do
      (def p (os/spawn ["tput" "cols"] :p {:out :pipe :err :pipe}))
      (def err (:wait p))
      (def tcols (when (zero? err) (-> (p :out) (:read :all) string/trim scan-number)))
      (min (or tcols max-width) max-width))
    cols))


(defn- long-opts
  ```
  Filter short options from option rules
  ```
  [opts]
  (filter (fn [[name _]] (not (one? (length name)))) (pairs opts)))


(defn- split-words
  ```
  Split a string into words
  ```
  [str]
  (def res @[])
  (def buf @"")
  (var i 0)
  (while (def curr-c (get str i))
    (++ i)
    (if (not (or (= 32 curr-c) (= 10 curr-c)) )
      (buffer/push buf curr-c)
      (when-let [next-c (get str i)]
        (++ i)
        (array/push res (string buf))
        (buffer/clear buf)
        (cond
          (= 10 next-c)
          (array/push res (string/from-bytes curr-c next-c))

          (= 32 next-c)
          nil

          (buffer/push buf next-c)))))
  (unless (empty? buf)
    (array/push res (string buf)))
  res)


(defn- stitch
  ```
  Stitch together components into a string, only adding a separator when
  adjacent components are non-nil
  ```
  [parts &opt sep]
  (default sep " ")
  (string/join (filter truthy? parts) sep))


(defn- indent-str
  ```
  Indent a string by a number of spaces at the start

  If a maximum width is provided, wrap and indent lines by the
  hanging padding.
  ```
  [str startp &opt hangp maxw]
  (default hangp 0)
  (default maxw cols)
  (def res (buffer (string/repeat " " startp)))
  (var currw (- hangp startp))
  (var first? true)
  (each word (split-words str)
    (cond
      first?
      (do
        (buffer/push res word)
        (+= currw (length word))
        (set first? false))

      (= "\n\n" word)
      (do
        (buffer/push res word (string/repeat " " hangp))
        (set currw hangp)
        (set first? true))

      (< (+ currw 1 (length word)) maxw)
      (do
        (buffer/push res " " word)
        (+= currw (+ 1 (length word))))

      (do
        (buffer/push res "\n" (string/repeat " " hangp) word)
        (set currw (+ hangp (length word))))))
  res)


# Usage messages

(defn usage-error
  ```
  Print the usage error message to stderr
  ```
  [& msg]
  (unless errored?
    (set errored? true)
    (eprint command ": " ;msg)
    (eprint "Try '" command " --help' for more information.")))


(defn- usage-parameters
  ```
  Print the usage descriptions for the parameters
  ```
  [info prules]
  (def pfrags @[])
  (var ppad 0)

  (each [name rule] prules
    (def usage-prefix
      (stitch [""
               (string/ascii-upper name)
               (when (or (= :single (rule :kind)) (= :multi (rule :kind)))
                 (or (rule :value-name) "<value>"))
               (rule :default)]))
    (def usage-help
      (stitch [(rule :help)
               (when (rule :default)
                 (string "(Default: " (rule :default) ")"))]))
    (array/push pfrags [usage-prefix usage-help])
    (set ppad (max (+ pad-inset (length usage-prefix)) ppad)))

  (unless (empty? pfrags)
    (print)
    (when (info :params)
      (print (info :params)))
    (each [prefix help] pfrags
      (def startp (- ppad (length prefix)))
      (print prefix (indent-str help startp ppad (- cols pad-right))))))


(defn- usage-options
  ```
  Print the usage descriptions for the options
  ```
  [info orules]
  (def ofrags @{:req @[] :opt @[]})
  (def opad @{:req 0 :opt 0})

  (each [name rule] (sort (long-opts orules))
    (def usage-prefix
      (stitch [""
               (if (rule :short)
                 (string "-" (rule :short) ",")
                 "   ")
               (string "--" name)
               (when (or (= :single (rule :kind)) (= :multi (rule :kind)))
                 (or (rule :name) (string/ascii-upper name)))
               ]))
    (def usage-help
      (stitch [(rule :help)
               (when (rule :default)
                 (string "(Default: " (rule :default) ")"))]))
    (def k (if (rule :required) :req :opt))
    (array/push (ofrags k) [usage-prefix usage-help])
    (put opad k (max (+ pad-inset (length usage-prefix)) (opad k))))

  (unless (and (zero? (ofrags :req))
               (zero? (ofrags :opt)))
    (print)
    (when (info :opts)
      (print (info :opts))))

  (each k [:req :opt]
    (unless (empty? (ofrags k))
      (print " " (if (= k :req) "Required" "Optional") ":")
      (each [prefix help] (ofrags k)
        (def startp (- (opad k) (length prefix)))
        (print prefix (indent-str help startp (opad k) (- cols pad-right)))))))


(defn- usage-subcommands
  ```
  Print the usage descriptions for the subcommands
  ```
  [info subcommands]
  (def sfrags @[])
  (var spad 0)

  (each [subcommand {:help help}] (sort (pairs subcommands))
    (def usage-prefix (string " " subcommand))
    (def usage-help (or help ""))
    (array/push sfrags [usage-prefix usage-help])
    (set spad (max (+ pad-inset (length usage-prefix)) spad)))

  (unless (empty? sfrags)
    (print)
    (when (info :subcmds)
      (print (info :subcmds)))
    (each [prefix help] sfrags
      (def startp (- spad (length prefix)))
      (print prefix (indent-str help startp spad (- cols pad-right))))
    (print)
    (print "For more information on each subcommand, type '" command " help <subcommand>'.")))


(defn- usage
  ```
  Print the usage message
  ```
  [&opt info [orules prules]]
  (set errored? true)

  (default info {})
  (default orules {})
  (default prules [])

  (if (info :examples)
    (each example (info :examples)
      (print example))
    (do
      (prin "usage: " command)
      (unless (zero? (length orules))
        (prin " [OPTION]..."))
      (each [name rule] prules
        (prin " ")
        (cond
          (and (rule :rest) (rule :required))
          (prin (string/ascii-upper name) "...")

          (rule :rest)
          (prin "[" (string/ascii-upper name) "...]")

          (prin (string/ascii-upper name))))
      (print)))

  (when (info :about)
    (print)
    (print (indent-str (info :about) 0)))

  (usage-parameters info prules)
  (usage-options info orules)

  (when (info :rider)
    (print)
    (print (indent-str (info :rider) 0))))


(defn- usage-with-subcommands
  ```
  Print the usage message with subcommands
  ```
  [info [orules subcommands]]
  (set errored? true)

  (if (info :examples)
    (each example (info :examples)
      (print example))
    (print "usage: " command " <subcommand> [args...]"))

  (when (info :about)
    (print)
    (print (indent-str (info :about) 0)))

  (usage-options info orules)
  (usage-subcommands info subcommands)

  (when (info :rider)
    (print)
    (print (indent-str (info :rider) 0))))


# Processing functions

(defn- convert
  ```
  Convert a textual value using the converter

  Internal functions are called if the converter is one of the following:

  * `:string` - Returns the value as-is.
  * `:integer` - Converts the value to an integer.
  ```
  [arg converter]
  (if (nil? converter)
    arg
    (cond
      (keyword? converter)
      (case converter
        :string
        arg

        :integer
        (let [[ok? res] (protect (scan-number arg))]
          (when (and ok? (int? res))
            res)))

      (function? converter)
      (converter arg))))


(defn- consume-option
  ```
  Consume an option
  ```
  [orules oargs args i &opt is-short?]
  (def arg (in args i))
  (def name (string/slice arg (if is-short? 1 2)))
  (if-let [rule (orules name)
           kind (rule :kind)]
    (case kind
      :flag
      (do
        (put oargs name true)
        (inc i))

      :count
      (do
        (put oargs name (-> (oargs name) (or 0) inc))
        (inc i))

      (if (or (= kind :single)
              (= kind :multi))
        (if-let [input (get args (inc i))]
          (if-let [val (convert input (rule :value))]
            (do
              (case kind
                :single (put oargs name val)
                :multi  (put oargs name (array/push (or (oargs name) @[]) val)))
              (+ 2 i))
            (usage-error "'" input "' is invalid value for " arg))
          (usage-error "no value after option of type " kind))))
    (usage-error "unrecognized option '" arg "'")))


(defn- rest-capture
  ```
  Get the parameter that captures the rest of the values (if defined)
  ```
  [rules]
  (when-let [[name rule] (last rules)]
    (and (rule :rest) [name rule])))


(defn- consume-param
  ```
  Consume a parameter
  ```
  [prules pargs args i]
  (def pos (length pargs))
  (if-let [[name rule] (or (get prules pos)
                           (rest-capture prules))]
    (if-let [arg (get args i)
             val (convert arg (rule :value))]
      (do
        (if (rule :rest)
          (put pargs name (array/push (or (pargs name) @[]) val))
          (put pargs name val))
        (inc i))
      (usage-error "'" arg "' is invalid value for " (string/ascii-upper name)))
    (usage-error "too many parameters passed")))


(defn- conform-args
  ```
  Conform arguments

  In particular, split short-options out if provided together.
  ```
  [args]
  (def res @[])
  (def grammar ~{:main      (+ :long-opt :short-opt ':rest)
                 :rest      (some 1)
                 :long-opt  (* '(* "--" (any (if-not "=" 1))) (? (* "=" ':rest)))
                 :short-opt (* '(* "-" 1) (any (% (* (constant "-") '1))))})
  (each arg args
    (array/concat res (peg/match grammar arg)))
  res)


(defn- conform-cmds
  ```
  Conform commands
  ```
  [args &opt has-subcommand?]
  (def pcmd (->> (get args 0) (string/split dir-sep) last))
  (if has-subcommand?
    (string pcmd " " (get args 1))
    pcmd))


(defn- conform-rules
  ```
  Conform rules
  ```
  [rules]
  (unless (even? (length rules))
    (errorf "number of elements in rules must be even: %p" rules))
  (def orules @{})
  (def prules @[])
  (var rest-capture? false)

  (put orules "help" {:kind  :help
                      :short "h"
                      :help  "Show this help message."})

  (each [k v] (partition 2 rules)
    (unless (or (string? k) (keyword? k))
      (errorf "names of rules must be strings or keywords: %p" k))
    (unless (or (struct? v) (table? v))
      (errorf "each rule must be struct or struct or table: %p" v))
    (unless (or (keyword? k) ({:flag true :count true :single true :multi true} (v :kind)))
      (errorf "each option rule must be of kind :flag, :count, :single or :multi: %p" v))
    (when (and (keyword? k) rest-capture?)
      (errorf "parameter rules cannot occur after rule that captures :rest: %p" v))
    (cond
      (string? k)
      (let [name (if (string/has-prefix? "--" k) (string/slice k 2) k)]
        (when (string/has-prefix? "-" name)
          (errorf "long option name must be provided: %p" name))
        (unless (> (length name) 2)
          (errorf "option names must be at least two characters: %p" name))
        (put orules name v)
        (put orules (v :short) v))

      (keyword? k)
      (do
        (array/push prules [k (if (v :rest) v (merge v {:required true}))])
        (set rest-capture? (v :rest)))))
  [orules prules])


# Parsing functions

(defn parse-args
  ```
  Parse the `(dyn :args)` value for a program

  This function takes a `config` struct containing the following keys:

  * `:rules` - Tuple of rules to use to parse the arguments.
  * `:info` - Struct of messages to use in help output.

  ### Rules

  The dynamic variable `:args` is parsed according to the rules tuple. This
  tuple is a series of key-value pairs.

  #### Options

  If the key is a string, the rule will be applied to option arguments
  (arguments that begin with a `-` or `--`). The value associated with each key
  is a struct that can have the following keys:

  * `:kind` - The kind of option. Values are `:flag`, `:count`, `:single` and
    `:multi`. A flag is a binary choice (e.g. true/false, on/off) that can
    only occur once. A count is a monotonically increasing integral value that
    can occur one or more times. A single is a value that can only occur once.
    A multi is a value that can occur one or more times.
  * `:short` - A single letter that is used with `-` rather than `--` and can
    be combined with other short options (e.g. `-lah`).
  * `:help` - The help text for the option, displayed in the usage message.
  * `:default` - A default value that is used if the option occurs.
  * `:required` - Whether the option is required to occur.
  * `:value` - A one-argument function that converts the text that is parsed to
    another kind of value. This function can be used for validation. If the
    return value is `nil`, the input is considered to fail parsing and a usage
    error message is printed instead.  Instead of a function, a keyword can be
    provided and Argy-Bargy's internal converter will be used instead. The
    valid keywords are :string and :integer.

  #### Parameters

  If the key is a keyword, the rule will be applied to parameter arguments
  (arguments that are not options). The value associated with each key is a
  struct that can have the following keys:

  * `:help` - Help text for the parameter, displayed in the usage message.
  * `:default` - Default value that is used if the parameter does not occur.
  * `:required` - Whether the parameter is required to exist.
  * `:value` - One-argument function that converts the textual value that is
    parsed to a value that will be returned in the return struct. This function
    can be used for validation. If the return value is `nil`, the input is
    considered to fail parsing and a usage error message is printed instead.
    Instead of a function, a keyword can be provided and Argy-Bargy's converter
    will be used instead. The valid keywords are `:string` and `:integer`.
  * `:rest` - Whether this rule should capture all following parameters. Only
    one parameter rule can have `:rest` set to `true`.

  ### Info

  The info struct contains messages that are used in the usage help. The struct
  can have the following keys:

  * `:about` - Message describing the program at a high level.
  * `:examples` - Collection of examples to be used in usage message.
  * `:opts` - Message printed immediately prior to listing of options.
  * `:params` - Message printed immediately prior to listing of parameters.
  * `:rider` - Message printed at the end of the usage message.

  ### Return Value

  Once parsed, the return value is a table with `:opts` and `:params` keys.
  The value associated with each key is a table containing the values parsed
  for each matching rule.
  ```
  [config &opt has-subcommand?]
  (set cols (get-cols))
  (set command (conform-cmds (dyn :args) has-subcommand?))
  (set errored? false)
  (def oargs @{})
  (def pargs @{})

  (def [orules prules] (conform-rules (get config :rules [])))

  (def all-args (conform-args (dyn :args)))
  (def num-args (length all-args))
  (var i (if has-subcommand? 2 1))

  (while (< i num-args)
    (def arg (get all-args i))
    (set i (cond
             (or (= "--help" arg) (= "-h" arg))
             (usage (config :info) [orules prules])

             (= "--" arg)
             (usage-error "illegal use of '--'")

             (string/has-prefix? "--" arg)
             (consume-option orules oargs all-args i)

             (= "-" arg)
             (usage-error "illegal use of '-'")

             (string/has-prefix? "-" arg)
             (consume-option orules oargs all-args i (string/slice arg 1))

             (consume-param prules pargs all-args i)))
    (when (nil? i)
      (break)))

  (unless errored?
    (each [name rule] prules
      (when (nil? (pargs name))
        (if (rule :required)
          (usage-error (string/ascii-upper name) " is required")
          (put pargs name (rule :default)))))

    (each [name rule] (long-opts orules)
      (when (nil? (oargs name))
        (when (rule :required)
          (usage-error "--" name " is required"))
        (put oargs name (rule :default))))

    @{:opts oargs :params pargs}))


(defn parse-args-with-subcommands
  ```
  Parse the `(dyn :args)` value for a program with subcommands

  This function takes a `config` struct and a `subcommands` struct.

  ### Config

  The `config` struct should contain the following keys:

  * `:rules` - Tuple of rules to use to parse the arguments.
  * `:info` - Struct of messages to use in help output.

  The rules tuple is similar to that in `parse-args` except that parameter
  rules are ignored.

  The info struct is similar to that in `parse-args` except that the `:params`
  key is ignored. A `:subcmds` key can be provided and is displayed immediately
  prior to the listing of subcommands.

  ### Subcommands

  The `subcommands` struct contains keys that are strings and values that are
  struct. Each key is the name of the subcommand. The struct includes the same
  keys as the `config` struct used in `parse-args`. A `:help` key can be
  provided and is used in the listing of subcommands.

  ### Return Value

  Once parsed, the return value is a table with `:opts`, `:params` and `:sub`
  keys.  The value associated with the `:opts` and `:params` keys are the same
  as that in `parse-args`. The value associated with the `:sub` key is the name
  of the subcommand provided.
  ```
  [config subcommands &opt stop-subcommand?]
  (default stop-subcommand? false)
  (set cols (get-cols))
  (set command (conform-cmds (dyn :args)))
  (set errored? false)
  (def oargs @{})
  (def pargs @{})
  (var subcommand nil)

  (def [orules _] (conform-rules (get config :rules [])))

  (def all-args (conform-args (dyn :args)))
  (def num-args (length all-args))
  (var i 1)

  (while (< i num-args)
    (def arg (get all-args i))
    (set i (cond
             (or (nil? arg) (= "--help" arg) (= "-h" arg))
             (usage-with-subcommands (config :info) [orules subcommands])

             (string/has-prefix? "--" arg)
             (consume-option orules oargs all-args i)

             (= "-" arg)
             (usage-error "illegal use of '-'")

             (string/has-prefix? "-" arg)
             (consume-option orules oargs all-args i (string/slice arg 1))

             stop-subcommand?
             (and (set subcommand arg) nil)

             (= "help" arg)
             (do
               (set subcommand (get all-args (++ i)))
               (def subconfig (subcommands subcommand))
               (cond
                 (nil? subcommand)
                 nil

                 (nil? subconfig)
                 (usage-error "unrecognized subcommand '" subcommand "'")

                 (do
                   (set command (string command " " subcommand))
                   (usage (subconfig :info) (conform-rules (get subconfig :rules []))))))

             (do
               (def subconfig (subcommands arg))
               (if (nil? subconfig)
                 (usage-error "unrecognized subcommand '" arg "'")
                 (with-dyns [:args (-> (array/slice all-args (dec i)) (put 0 command))]
                   (def subargs (parse-args subconfig true))
                   (unless (nil? subargs)
                     (set subcommand arg)
                     (merge-into oargs (subargs :opts))
                     (merge-into pargs (subargs :params))))))))
    (when (nil? i)
      (break)))

  (if errored?
    (os/exit 1)
    (if (nil? subcommand)
      (usage-with-subcommands (config :info) [orules subcommands])
      @{:opts oargs :params pargs :sub subcommand})))
