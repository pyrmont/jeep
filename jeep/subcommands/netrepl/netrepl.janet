###
### netrepl.janet
###
### A simple async networked repl (both client and server) with a remote debugger
### and the ability to repl into existing environments.
###

(use /deps/msg)
(use /deps/ev-utils)

(def default-host
  "Default host to run server on and connect to."
  "127.0.0.1")

(def default-port
  "Default port to run the net repl."
  "9365")

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
      (put e :pretty-format "%.20Q"))))

# NETREPL Protocol
#
# Clients don't need to support steps 4. and 5. if they never send messages prefixed
# with 0xFF or 0xFE bytes. These bytes should not occur in normal Janet source code and
# are not even valid utf8.
#
# Any message received by the client that begins with 0xFF should result in printing
# the message to a console, but not otherwise interrupt the flow of the protocol. This
# easily allows for partial results. A server should not send messages leading with 0xFF
# to the client unless the client is created with the :auto-flush connection setting.
#
# Any message received by the client that begins with 0xFE will discard this first byte
# and continue processing as usual.
#
# 1. server <- {connection settings, including client name} <- client
#   1a. If msg starts with 0xFF, parse message as (-> msg (slice 1) parse) and extract
#       the :name key as the name. Other connection settings can be stored here.
#   1b. If msg does not start with 0xFF, the message is treated as the client name.
#       Other options are considered nil.
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
#   6b. Unless auto-flush is enabled, server -> {(dyn :out) and (dyn :err) (empty at first)} -> client
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
  (fn on-signal [f x]
    (case (fiber/status f)
      :dead (do (put e '_ @{:value x}) (pp x))
      (if (e :debug)
        (enter-debugger f x)
        (do (debug/stacktrace f x "") (eflush))))))

(defn server
  "Start a repl server. The default host is \"127.0.0.1\" and the default port
  is \"9365\". Calling this will start a TCP server that exposes a
  repl into the given env. If no env is provided, a new env will be created
  per connection. If env is a function, that function will be invoked with
  the name and stream on each connection to generate an environment. `cleanup` is
  an optional function that will be called for each stream after closing if provided.
  `welcome-msg` is an optional string or function (welcome-msg client-name) to generate
  a message to print for the client on connection."
  [&opt host port env cleanup welcome-msg]
  (default host default-host)
  (default port default-port)
  (eprint "Starting networked repl server on " host ", port " port "...")
  (def name-set @{})
  (net/server
    host port
    (fn repl-handler [stream]

      # Setup closures and state
      (var name "<unknown>")
      (var last-flush 0)
      (def outbuf @"")
      (def nurse (nursery))
      (defn wrapio [f] (fn [& a] (with-dyns [:out outbuf :err outbuf] (f ;a))))
      (def recv (make-recv stream))
      (def send (make-send stream))
      (var auto-flush false)
      (var is-first true)
      (var keep-flushing false)
      (defn flush1
        "Write stdout and stderr back to client if there is something to write or enough time has passed."
        []
        (def now (os/clock))
        (when (or (next outbuf) (< (+ 2 last-flush) now))
          (def msg (string "\xFF" outbuf))
          (buffer/clear outbuf)
          (send msg)
          (set last-flush now)))
      (defn flusher
        "Flush until canceled, or early exit."
        []
        (ev/sleep 0)
        (while keep-flushing
          (flush1)
          (ev/sleep 0.1)))
      (defn get-name
        "Get client name and settings"
        []
        (def msg (recv))
        (def leader (get msg 0))
        (if (= 0xFF leader)
          (let [opts (-> msg (slice 1) parse)]
            (set auto-flush (get opts :auto-flush))
            (set name (get opts :name)))
          (set name msg)))
      (defn getline-async
        [prmpt buf]
        (if auto-flush
          (flush1)
          (if is-first # step 6b. is redundant with auto-flush, but needed for clients like Conjure.
            (set is-first false)
            (let [b (get outbuf 0)]
              (when (or (= b 0xFF) (= b 0xFE))
                (buffer/blit outbuf outbuf 1 0 -1)
                (put outbuf 0 0xFE))
              (send outbuf)
              (buffer/clear outbuf))))
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
        (getline-async (string name ":" lno ":" delim " ") buf))

      # Run REPL session

      (spawn-nursery
        nurse
        # Get name and client settings
        (set name (or (get-name) (break)))
        (while (get name-set name)
          (set name (string name (gensym))))
        (put name-set name true)
        (eprint "client " name " connected")
        (def e (coerce-to-env env name stream))
        (def p (parser/new))
        # Print welcome message
        (when (and welcome-msg auto-flush)
          (def msg
            (if (bytes? welcome-msg)
              welcome-msg
              (welcome-msg name)))
          (when msg
            (send (string/format
                    "\xFF%s"
                    msg))))
        # REPL run-conext
        (->
          (run-context
            {:env e
             :chunks chunk
             :on-status (make-onsignal getline-async e e 1)
             :on-compile-error (wrapio bad-compile)
             :on-parse-error (wrapio bad-parse)
             :evaluator
             (fn evaluate-wrapped [x &]
               (setdyn :out outbuf)
               (setdyn :err outbuf)
               (if auto-flush
                 (do
                   (set keep-flushing true)
                   (def f (go-nursery nurse flusher))
                   (edefer (set keep-flushing false)
                     (def result (x))
                     (set keep-flushing false)
                     (flush1)
                     result))
                 (x)))
             :source "repl"
             :parser p})
          coro
          (fiber/setenv (table/setproto @{:out outbuf :err outbuf :parser p} e))
          resume))

      # Wait for nursery
      (protect (join-nursery nurse))

      # Clean up
      (:close stream)
      (put name-set name nil)
      (eprint "closing client " name)
      (when cleanup (cleanup stream)))))
