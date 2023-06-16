(import documentarian :as doc)


(defn- remove-rules
  [rules targets]
  (var discard? false)
  (def result @[])
  (each r rules
    (cond
      discard?
      (set discard? false)

      (targets r)
      (set discard? true)

      (array/push result r)))
  result)


(defn- subcommand [meta args]
  (def globals (args :globals))
  (def opts (args :opts))
  (put (args :opts) "local" ((args :globals) "local"))
  (put (args :opts) "tree" ((args :globals) "tree"))
  (doc/generate-doc (doc/args->opts args)))


(def config
  {:info {:about `Generate API documentation

                 The doc subcommand generates an API document by analysing the
                 docstrings in the source files specified in a project.janet
                 file.`}
   :rules (-> (doc/config :rules)
              (remove-rules {"--local" true "--tree" true}))
   :help "Generate API documentation."
   :fn   subcommand})
