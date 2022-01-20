###
### netrepl.janet
###
### A simple async networked repl (both client and server) with a remote debugger
### and the ability to repl into existing environments.
###

(use ./msg)

(def default-host
  "Default host to run server on and connect to."
  "127.0.0.1")

(def default-port
  "Default port to run the net repl."
  "9365")

(defn- run-contexts
  ```
  Run one of a number of contexts. The version of `run-context` provided in the
  Core API evaluates all code within one context. Jeep's netrepl will select a
  context based on the filename of the buffer being evaluated.
  ```
  [opts]
  (def {:env default-env
        :chunks chunks
        :on-status onstatus
        :on-compile-error on-compile-error
        :on-compile-warning on-compile-warning
        :on-parse-error on-parse-error
        :fiber-flags guard
        :evaluator evaluator
        :source default-where
        :parser parser
        :read read
        :expander expand} opts)
  (default default-env (or (fiber/getenv (fiber/current)) @{}))
  (default chunks (fn [buf p] (getline "" buf default-env)))
  (default onstatus debug/stacktrace)
  (default on-compile-error bad-compile)
  (default on-compile-warning warn-compile)
  (default on-parse-error bad-parse)
  (default evaluator (fn evaluate [x &] (x)))
  (default default-where :<anonymous>)
  (default guard :ydt)

  (var env default-env)
  (var where default-where)

  (if (string? where)
    (put env :current-file where))

  # Evaluate 1 source form in a protected manner
  (def lints @[])
  (def lint-levels
    {:none 0
     :relaxed 1
     :normal 2
     :strict 3
     :all math/inf})
  (defn eval1 [source &opt l c]
    (def source (if expand (expand source) source))
    (var good true)
    (var resumeval nil)
    (def f
      (fiber/new
        (fn []
          (array/clear lints)
          (def res (compile source env where lints))
          (unless (empty? lints)
            # Convert lint levels to numbers.
            (def levels (get env :lint-levels lint-levels))
            (def lint-error (get env :lint-error))
            (def lint-warning (get env :lint-warn))
            (def lint-error (or (get levels lint-error lint-error) 0))
            (def lint-warning (or (get levels lint-warning lint-warning) 2))
            (each [level line col msg] lints
              (def lvl (get lint-levels level 0))
              (cond
                (<= lvl lint-error) (do
                                      (set good false)
                                      (on-compile-error msg nil where (or line l) (or col c)))
                (<= lvl lint-warning) (on-compile-warning msg level where (or line l) (or col c)))))
          (when good
            (if (= (type res) :function)
              (evaluator res source env where)
              (do
                (set good false)
                (def {:error err :line line :column column :fiber errf} res)
                (on-compile-error err errf where (or line l) (or column c))))))
        guard))
    (fiber/setenv f env)
    (while (fiber/can-resume? f)
      (def res (resume f resumeval))
      (when good (set resumeval (onstatus f res)))))

  # The parser object
  (def p (or parser (parser/new)))
  (def p-consume (p :consume))
  (def p-produce (p :produce))
  (def p-status (p :status))
  (def p-has-more (p :has-more))

  (defn parse-err
    "Handle parser error in the correct environment"
    [p where]
    (def f (coro (on-parse-error p where)))
    (fiber/setenv f env)
    (resume f))

  (defn produce []
    (def tup (p-produce p true))
    [(in tup 0) ;(tuple/sourcemap tup)])

  # Environments
  (def envs @{})
  (defn select-env []
    (cond
      (def mod-env (get module/cache where))
      mod-env
      (def pre-env (get envs where))
      pre-env
      (when (string? where)
        (def new-env (make-env default-env))
        (put envs where new-env)
        new-env)
      default-env))

  # Loop
  (def buf @"")
  (var parser-not-done true)
  (while parser-not-done
    (if (env :exit) (break))
    (buffer/clear buf)
    (match (chunks buf p)
      :cancel
      (do
        # A :cancel chunk represents a cancelled form in the REPL, so reset.
        (:flush p)
        (buffer/clear buf))

      [:source new-where]
      (do
        (set where new-where)
        (if (string? new-where)
          (put env :current-file new-where)))

      (do
        (set env (select-env))
        (var pindex 0)
        (var pstatus nil)
        (def len (length buf))
        (when (= len 0)
          (:eof p)
          (set parser-not-done false))
        (while (> len pindex)
          (+= pindex (p-consume p buf pindex))
          (while (p-has-more p)
            (eval1 ;(produce))
            (if (env :exit) (break)))
          (when (= (p-status p) :error)
            (parse-err p where)
            (if (env :exit) (break)))))))

  # Check final parser state
  (unless (env :exit)
    (while (p-has-more p)
      (eval1 ;(produce))
      (if (env :exit) (break)))
    (when (= (p-status p) :error)
      (parse-err p where)))

  (put env :exit nil)
  (in env :exit-value env))

# Specifying the Environment
#
# Provide various ways to produce the environment to repl into.
# 1. an environment factory function, called for each connection.
# 2. an env (table value) - this means every connection will share the
#    same environment
# 3. default env, made via make-env with nice printing for each new connection.

(defn- coerce-to-env
  "Get an environment for the repl."
  [env name stream]
  (cond
    (function? env) (env name stream)
    (not= nil env) env
    (let [e (make-env)]
      (put e :pretty-format "%.20M"))))

# NETREPL Protocol
#
# Clients don't need to support steps 4. and 5. if they never send messages prefixed
# with 0xFF or 0xFE bytes. These bytes should not occur in normal Janet source code and
# are not even valid utf8.
#
# 1. server <- {user specified name of client (will be shown in repl)} <- client
# 2. server -> {repl prompt (no newline)} -> client
# 3. server <- {one chunk of input (msg)} <- client
# 4. If (= (msg 0) 0xFF)
#   4a. (def result (-> msg (slice 1) parse eval protect))
#   4b. server -> result -> client
#   4c. goto 3.
# 5. If (= (msg 0) 0xFE)
#   5a. Return msg as either:
#       i. a keyword if the msg contains a command (e.g. :cancel)
#       ii. an array if the msg contains a command and arguments (e.g. @[:source "path/to/source"]
#   5b. goto 6b.
# 6. Otherwise
#   6a. Send chunk to repl input stream
#   6b. server -> {(dyn :out) and (dyn :err) (empty at first)} -> client
#   6c. goto 2.

(def- cmd-peg
  "Peg for matching incoming netrepl commands"
  (peg/compile
    ~{:main (* :command (any (* :space :argument)))
      :space (some (set " \t"))
      :identifier (some :S)
      :command (/ ':identifier ,keyword)
      :argument (/ '(+ :quoted-arg :bare-arg) ,parse)
      :bare-arg :identifier
      :quoted-arg (* `"` (any (+ (* `\` 1) (if-not `"` 1))) `"`)}))

(defn- make-onsignal
  "Make an onsignal handler for debugging. Since the built-in repl
  calls getline which blocks, we use our own debugging functionality."
  [getter env e level]
  (defn enter-debugger
    [f x]
    (def nextenv (make-env env))
    (put nextenv :fiber f)
    (put nextenv :debug-level level)
    (put nextenv :signal x)
    (merge-into nextenv debugger-env)
    (debug/stacktrace f x "")
    (eflush)
    (defn debugger-chunks [buf p]
      (def status (parser/state p :delimiters))
      (def c ((parser/where p) 0))
      (def prpt (string "debug[" level "]:" c ":" status "> "))
      (getter prpt buf))
    (print "entering debug[" level "] - (quit) to exit")
    (flush)
    (repl debugger-chunks (make-onsignal getter env nextenv (+ 1 level)) nextenv)
    (print "exiting debug[" level "]")
    (flush)
    (nextenv :resume-value))
  (fn [f x]
    (if (= :dead (fiber/status f))
      (do (put e '_ @{:value x}) (pp x))
      (if (e :debug)
        (enter-debugger f x)
        (do (debug/stacktrace f x "") (eflush))))))

(defn- source-loader
  ```
  Load Janet source code. This replaces the default loader. It creates an
  environment using the `parent-env` parameter. This is useful for persisting
  dynamic bindings across modules.
  ```
  [parent-env]
  (fn [path args]
    (put module/loading path true)
    (defer (put module/loading path nil)
      (dofile path :env (make-env parent-env) ;args))))

(defn server
  "Start a repl server. The default host is \"127.0.0.1\" and the default port
  is \"9365\". Calling this will start a TCP server that exposes a
  repl into the given env. If no env is provided, a new env will be created
  per connection. If env is a function, that function will be invoked with
  the name and stream on each connection to generate an environment. `cleanup` is
  an optional function that will be called for each stream after closing if provided."
  [&opt host port env cleanup]
  (default host default-host)
  (default port default-port)
  (print "Starting networked repl server on " host ", port " port "...")
  (def name-set @{})
  (net/server
    host port
    (fn repl-handler [stream]
      (var name "<unknown>")
      (def outbuf @"")
      (defn wrapio [f] (fn [& a] (with-dyns [:out outbuf :err outbuf] (f ;a))))
      (defer (do
               (:close stream)
               (put name-set name nil)
               (when cleanup (cleanup stream)))
        (def recv (make-recv stream))
        (def send (make-send stream))
        (set name (or (recv) (break)))
        (while (get name-set name)
          (set name (string name "_")))
        (put name-set name true)
        (print "client " name " connected")
        (def e (coerce-to-env env name stream))
        (put module/loaders :source (source-loader e))
        (def p (parser/new))
        (var is-first true)
        (defn getline-async
          [prmpt buf]
          (if is-first
            (set is-first false)
            (do
              (send outbuf)
              (buffer/clear outbuf)))
          (send prmpt)
          (var ret nil)
          (while (def msg (recv))
            (cond
              (= 0xFF (in msg 0))
              (send (string/format "%j" (-> msg (slice 1) parse eval protect)))
              (= 0xFE (in msg 0))
              (do
                (def cmd (peg/match cmd-peg msg 1))
                (if (one? (length cmd))
                  (set ret (first cmd))
                  (set ret cmd))
                (break))
              (do (buffer/push-string buf msg) (break))))
          ret)
        (defn chunk
          [buf p]
          (def delim (parser/state p :delimiters))
          (def lno ((parser/where p) 0))
          (getline-async (string name ":" lno ":" delim  " ") buf))
        (->
          (run-contexts
            {:env e
             :chunks chunk
             :on-status (make-onsignal getline-async e e 1)
             :on-compile-error (wrapio bad-compile)
             :on-parse-error (wrapio bad-parse)
             :evaluator (fn [x &] (setdyn :out outbuf) (setdyn :err outbuf) (x))
             :source :netrepl
             :parser p})
          coro
          (fiber/setenv (table/setproto @{:out outbuf :err outbuf :parser p} e))
          resume))
      (print "closing client " name))))

(defn client
  "Connect to a repl server. The default host is \"127.0.0.1\" and the default port
  is \"9365\"."
  [&opt host port name]
  (default host default-host)
  (default port default-port)
  (default name (string "[" host ":" port "]"))
  (with [stream (net/connect host port)]
    (def recv (make-recv stream))
    (def send (make-send stream))
    (send name)
    (while true
      (def p (recv))
      (if (not p) (break))
      (def line (getline p @"" root-env))
      (if (empty? line) (break))
      (send (if (keyword? line) (string "\xFE" line) line))
      (prin (or (recv) "")))))

