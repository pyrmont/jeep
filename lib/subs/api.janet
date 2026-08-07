(import ../util)
(import ../../deps/musty)

(def- helps
  {:input
   `The <path> to the info.jdn file describing the bundle.`
   :drop
   `Drop the <prefix> from all module names.`
   :match
   `Include bindings from a file only if its path matches (or begins with)
   <path>. Bindings from other files are not put in the API document. This
   option can be invoked multiple times.`
   :no-match
   `Exclude bindings from a file if its path matches (or begins with) <path>.
   Bindings from other files are put in the API document. This option can be
   invoked multiple times.`
   :output
   `Write the API document to <path>. Use '-' to output to stdout.`
   :private
   `Include private bindings in the API document.`
   :template
   `The <path> to a file containing the Mustache template.`
   :url
   `Prepend the <url> to all links.`
   :about
   `Generates an API document for a bundle. This is done by scanning the files
   and directories described in the bundle's info file. For more information,
   see jeep-api(1).`
   :help
   `Generate an API document for the current bundle.`})

(def config
  {:rules [:input {:proxy "path"
                   :default "info.jdn"
                   :hide? true
                   :help (helps :input)}
           "--drop" {:kind :single
                     :short "d"
                     :proxy "prefix"
                     :help (helps :drop)}
           "--match" {:kind :multi
                      :short "m"
                      :proxy "path"
                      :help (helps :match)}
           "--no-match" {:kind :multi
                         :short "M"
                         :proxy "path"
                         :help (helps :no-match)}
           "--output" {:kind :single
                       :default "api.md"
                       :short "o"
                       :proxy "path"
                       :help (helps :output)}
           "--private" {:kind :flag
                        :short "p"
                        :help (helps :private)}
           "--template" {:kind :single
                         :short "t"
                         :proxy "path"
                         :help (helps :template)}
           "--url" {:kind  :single
                    :short "u"
                    :proxy "url"
                    :help (helps :url)}
           "---"]
   :info {:about (helps :about)}
   :help (helps :help)})

(def- default-template
  ````
  # {{bundle-name}} API

  {{#bundle-doc}}
  {{&bundle-doc}}

  {{/bundle-doc}}
  {{#modules}}
  {{#ns}}
  ## {{ns}}

  {{/ns}}
  {{#items}}{{^first}}, {{/first}}[{{name}}](#{{in-link}}){{/items}}

  {{#doc}}
  {{&doc}}

  {{/doc}}
  {{#items}}
  ## {{name}}

  **{{kind}}** {{#private?}}| **private**{{/private?}} {{#link}}| [source][{{num}}]{{/link}}

  {{#sig}}
  ```janet
  {{&sig}}
  ```
  {{/sig}}

  {{&docstring}}

  {{#link}}
  [{{num}}]: {{link}}
  {{/link}}

  {{/items}}
  {{/modules}}
  ````)

(defn- link
  [{:file file :line line} bundle-root url]
  (default url "")
  (if (nil? file) (break))
  (def http-link (->> (string/replace (string bundle-root util/sep) url file)
                      (string/replace util/sep "/")))
  (string http-link "#L" line))

(defn- internal-link
  [name headings]
  # uses the algorithm at https://github.com/gjtorikian/html-pipeline/blob/main/lib/html/pipeline/toc_filter.rb
  (def key (-> (peg/match ~{:main    (% (any (+ :kept :changed :ignored)))
                            :kept    (<- (+ :w+ (set "_-")))
                            :changed (/ (<- " ") "-")
                            :ignored 1}
                          name)
               (first)))
  (def i (get headings key 0))
  (put headings key (inc i))
  (if (zero? i)
    key
    (string key "-" i)))

(defn- binding->item
  ```
  Prepares the fields for the template
  ```
  [item num first? opts]
  {:num       num
   :first     first?
   :name      (item :name)
   :ns        (item :ns)
   :kind      (string (item :kind))
   :private?  (item :private?)
   :sig       (or (item :sig)
                  (and (not (nil? (item :value)))
                       (string/format "%q" (item :value))))
   :docstring (item :docstring)
   :link      (link item (opts :bundle-root) (opts :url))
   :in-link   (internal-link (item :name) (opts :headings))})

(defn- bindings->modules
  ```
  Splits an array of bindings into an array of modules.
  ```
  [bindings opts]
  (def modules @[])
  (var curr-ns nil)
  (var items nil)
  (var module nil)
  (var first? false)
  (loop [i :range [0 (length bindings)]
           :let [binding (get bindings i)]]
    (def ns (cond
              # no namespace
              (= "" (binding :ns))
              false
              # top-level init
              (= "init" (binding :ns))
              false
              # default
              (binding :ns)))
    (if (= curr-ns ns)
      (set first? false)
      (do
        (set curr-ns ns)
        (set items @[])
        (set module @{:ns curr-ns :items items})
        (set first? true)
        (array/push modules module)))
    (if (binding :doc)
      (put module :doc (binding :doc))
      (array/push items (binding->item binding (inc i) first? opts))))
  modules)

(defn- emit-markdown
  [bindings template-path opts]
  (def template (if template-path (slurp template-path) default-template))
  (put opts :modules (bindings->modules bindings opts))
  (musty/render template opts))

(defn- source-map
  [meta]
  (or (meta :source-map)
      (let [ref (-?> (meta :ref) first)]
        (if (= :function (type ref))
          (let [code       (disasm ref)
                file       (code :source)
                [line col] (-> (code :sourcemap) first)]
            [file line col])
          [nil nil nil]))))

(defn- binding-details
  [name meta maybe-ns]
  (def ns (or (meta :ns) maybe-ns))
  (def value (or (meta :value) (first (meta :ref))))
  (def [file line _] (source-map meta))
  (def kind (cond (meta :macro) :macro
                  (meta :kind) (meta :kind)
                  (type value)))
  (def private? (meta :private))
  (def docs (meta :doc))
  (def [sig docstring] (if (and docs (string/find "\n\n" docs))
                         (string/split "\n\n" docs 0 2)
                         [nil docs]))
  {:name      name
   :ns        ns
   :value     value
   :kind      kind
   :private?  private?
   :sig       sig
   :docstring docstring
   :file      file
   :line      line})

(defn- path->ns
  [path bundle-root drop-prefix]
  (var begin (if (util/abspath? path)
               (+ (length bundle-root) (length util/sep))
               0))
  (when drop-prefix
    (+= begin (length drop-prefix)))
  (def end (cond
             (string/has-suffix? ".janet" path) -7
             (string/has-suffix? ".so" path) -3
             (string/has-suffix? ".dll" path) -4))
  (->> (string/slice path begin end)
       (string/replace util/sep "/")))

(defn- alias-meta?
  [meta]
  (and (one? (length meta))
       (not (nil? (table/getproto meta)))))

(defn- find-aliases
  ```
  Finds possible aliases

  Bindings that are imported into a namespace and then exported have a `meta`
  length of 1 and inherit the original binding's metadata through their
  prototype. This can be used as a heuristic to build a table of possible aliases
  that can be used in the `extract-bindings` function. A more robust implementation
  would store the value of the aliased binding and use that later to check.
  ```
  [envs bundle-root drop-prefix]
  (def aliases @{})
  (each [path env] (pairs envs)
    (def ns (path->ns path bundle-root drop-prefix))
    (each [name meta] (pairs env)
      (when (alias-meta? meta)
        (put aliases name ns))))
  aliases)

(defn- document-name?
  [name]
  (case name :doc true (symbol? name)))

(defn- extract-bindings
  [envs opts]
  (def bundle-root (get opts :bundle-root))
  (def drop-prefix (get opts :drop-prefix))
  (def include-private? (get opts :include-private?))
  (def aliases (find-aliases envs bundle-root drop-prefix))
  (defn ns-or-alias [name ns]
    (def alias (aliases name))
    (if (and (not (nil? alias))
             (string/has-prefix? alias ns))
      alias
      ns))
  (def bindings @[])
  (each [path env] (pairs envs)
    (def ns (path->ns path bundle-root drop-prefix))
    (each [name meta] (pairs env)
      (when (and (document-name? name)
                 (or (not (meta :private))
                     include-private?))
        (cond
          # top-level 'namespace'
          (= :doc name)
          (array/push bindings {:ns ns :doc meta})
          # aliases
          (alias-meta? meta)
          (->> (binding-details name (table/getproto meta) ns)
               (array/push bindings))
          # ordinary bindings
          (->> (ns-or-alias name ns)
               (binding-details name meta)
               (array/push bindings))))))
  (sort-by (fn [b] (string (b :ns) (b :name))) bindings))

(defn- extract-env
  [path syspath]
  (def env (make-env))
  (put env :syspath syspath)
  (dofile path :env env)
  (unless (nil? env)
    (put env :current-file nil)
    (put env :source nil))
  env)

(defn- extract-native-env
  [name]
  (require name))

(defn- parse-info
  [info-file]
  (assertf (os/stat info-file) "file %s does not exist" info-file)
  (def info (-> (slurp info-file) (parse)))
  (def libs (get-in info [:artifacts :libraries]))
  (def natives (get-in info [:artifacts :natives]))
  (assert (or (and (indexed? libs) (not (empty? libs)))
              (and (indexed? natives) (not (empty? natives))))
          "info file does not have libraries under [:artifacts :libraries]")
  (when libs
    (assert (indexed? libs) "info file does not have array/tuple under [:artifacts :libraries]")
    (each lib libs
      (def files (get lib :paths))
      (assert files "info file has a library without paths under [:artifacts :libraries]")
      (assert (indexed? files) "info file has a library whose paths are not an array/tuple under [:artifacts :libraries]")))
  (when natives
    (assert (indexed? natives) "info file does not have array/tuple under [:artifacts :natives]")
    (each native-artifact natives
      (assert (get native-artifact :name) "info file has a native without a name under [:artifacts :natives]")))
  info)

(defn- abspath
  [path root]
  (if (util/abspath? path)
    path
    (os/realpath (string root util/sep path))))

(defn- filter-paths
  [libs bundle-root matches no-matches]
  (def res @[])
  (def includes (if matches (map (fn [s] (abspath s bundle-root)) matches)))
  (def excludes (if no-matches (map (fn [s] (abspath s bundle-root)) no-matches)))
  (def abspaths
    (do
      (def abs-res @[])
      (def check @[])
      (each l (or libs [])
        (array/concat check (map (fn [s] (abspath s bundle-root)) (get l :paths))))
      # (def check (map (fn [s] (abspath s bundle-root)) paths))
      (each c check
        (case (os/stat c :mode)
          :file
          (cond
            (string/has-suffix? ".janet" c)
            (array/push abs-res c))
          :directory
          (each entry (os/dir c)
            (unless (index-of entry ["." ".."])
              (array/push check (string c util/sep entry))))))
      abs-res))
  (each p abspaths
    (def add? (if includes
                (find (fn [i] (string/has-prefix? i p))
                      includes)
                (if excludes
                  (not (find (fn [e] (string/has-prefix? e p))
                             excludes))
                  true)))
    (if add? (array/push res p)))
  res)

(defn- filter-natives
  [natives bundle-root matches no-matches]
  (def includes (if matches (map (fn [s] (abspath s bundle-root)) matches)))
  (def excludes (if no-matches (map (fn [s] (abspath s bundle-root)) no-matches)))
  (filter
    (fn [native-artifact]
      (def paths (map (fn [s] (abspath s bundle-root)) (get native-artifact :files [])))
      (if includes
        (find (fn [p]
                (find (fn [i] (string/has-prefix? i p)) includes))
              paths)
        (if excludes
          (not (find (fn [p]
                       (find (fn [e] (string/has-prefix? e p)) excludes))
                     paths))
          true)))
    (or natives [])))

(defn- parent
  [path]
  (util/parent (os/realpath path)))

(defn- generate-doc
  ```
  Generates an API document for a bundle
  ```
  [&named drop-prefix include-private? input-path output-path matches no-matches
   syspath template url]
  (def info (parse-info input-path))
  (def bundle-root (parent input-path))
  # make opts
  (def opts @{:bundle-doc (get info :doc)
              :bundle-name (get info :name)
              :bundle-root bundle-root
              :drop-prefix drop-prefix
              :headings @{}
              :include-private? include-private?
              :input-path input-path
              :output-path output-path
              :template template
              :url url})
  # add _build dir to places to check
  (defn check-build-dir [name]
    (def path (string bundle-root util/sep "_build" util/sep "release"
                      util/sep (module/expand-path name ":all::native:")))
    (when (= :file (os/stat path :mode))
      (string/replace-all "\\" "/" path)))
  (array/push module/paths [check-build-dir :native])
  # determine sources to scan
  (def paths (filter-paths (get-in info [:artifacts :libraries]) bundle-root matches no-matches))
  (def natives (filter-natives (get-in info [:artifacts :natives]) bundle-root matches no-matches))
  # get environments
  (def envs (tabseq [p :in paths] p (extract-env p syspath)))
  (each native-artifact natives
    (def name (get native-artifact :name))
    (put envs name (extract-native-env name)))
  # get bindings
  (def bindings (extract-bindings envs opts))
  # generate markdown
  (def document (emit-markdown bindings template opts))
  # write output
  (if (= "-" output-path)
    (print document)
    (spit output-path document)))

(defn run
  [args]
  (def syspath (if (get-in args [:opts "local"]) "_system"))
  (def input-path (get-in args [:sub :params :input]))
  (def {"drop" drop-prefix
        "private" include-private?
        "output" output-path
        "match" matches
        "no-match" no-matches
        "template" template
        "url" url} (get-in args [:sub :opts]))
  (generate-doc :drop-prefix drop-prefix
                :include-private? include-private?
                :input-path input-path
                :output-path output-path
                :matches matches
                :no-matches no-matches
                :syspath syspath
                :template template
                :url url)
  (print "Document generated."))
