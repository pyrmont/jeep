(import ../../deps/honeycut :as honeycut)
(import ../../deps/honeycut/lib/zipper :as zipper)

(def- sep (get {:windows "\\" :mingw "\\" :cygwin "\\"} (os/which) "/"))
(def- suffix "res/tools/patch-spork.janet")
(def- current-file (dyn :current-file))
(def- normal-file (string/replace-all "\\" "/" current-file))
(assert (string/has-suffix? suffix normal-file) "unexpected patch-spork source path")
(def- root (string/slice current-file 0 (- (length current-file) (length suffix))))

(defn- defn-location [tree name]
  (def matches @[])
  (var loc (zipper/zip tree))
  (while loc
    (when (= :tuple (first (zipper/node loc)))
      (when-let [head (zipper/down-skip loc)]
        (when-let [def-name (zipper/right-skip head)]
          (when (and (= 'defn (zipper/value head))
                     (= name (zipper/value def-name)))
            (array/push matches loc)))))
    (set loc (zipper/df-next loc)))
  (assertf (= 1 (length matches))
           "expected one Spork definition named %s, found %d"
           name (length matches))
  (first matches))

(defn- form-locations [tree form]
  (def matches @[])
  (var loc (zipper/zip tree))
  (while loc
    (when (and (= :tuple (first (zipper/node loc)))
               (= form (zipper/value loc)))
      (array/push matches loc))
    (set loc (zipper/df-next loc)))
  matches)

(defn- previous-values [loc n]
  (def values @[])
  (var prev loc)
  (loop [_ :range [0 n]]
    (set prev (zipper/left-skip prev))
    (assert prev "not enough preceding forms in Spork source")
    (array/push values (zipper/value prev)))
  values)

(defn- patch-unused-license [tree]
  (def project-loc (defn-location tree 'declare-project))
  (def upstream-comment [:comment "# unused"])
  (def patch-comment [:comment "# patched by Jeep's prep hook"])
  (def comments @[])
  (def patch-comments @[])
  (var child (zipper/down project-loc))
  (while child
    (when (= upstream-comment (zipper/node child))
      (array/push comments child))
    (when (= patch-comment (zipper/node child))
      (array/push patch-comments child))
    (set child (zipper/right child)))
  (assertf (= 1 (length comments))
           "expected one unused comment in Spork's declare-project, found %d"
           (length comments))
  (def comment-loc (first comments))
  (def upstream ['author 'dependencies 'tag 'url 'description 'version 'repo])
  (def patched ['license ;upstream])
  (def values (previous-values comment-loc (length patched)))
  (cond
    (and (= 1 (length patch-comments))
         (= patched (tuple ;values)))
    tree
    (and (empty? patch-comments)
         (= upstream (slice values 0 (length upstream))))
    (do
      (var repo-loc comment-loc)
      (loop [_ :range [0 (length upstream)]]
        (set repo-loc (zipper/left-skip repo-loc)))
      (set repo-loc
           (zipper/insert-left
             repo-loc
             (honeycut/parse "# patched by Jeep's prep hook\n  ")))
      (var author-loc repo-loc)
      (loop [_ :range [0 (- (length upstream) 1)]]
        (set author-loc (zipper/right-skip author-loc)))
      (zipper/root
        (zipper/insert-right author-loc (honeycut/parse " license"))))
    (errorf "could not cleanly patch unused license in Spork's declare-project")))

(defn- patch-quickbin-copy [tree]
  (def quickbin-loc (defn-location tree 'quickbin))
  (def quickbin-tree (zipper/node quickbin-loc))
  (def upstream '(sh/copy target output))
  (def copy-file '(sh/copy-file target output))
  (def chmod '(os/chmod output 8r755))
  (def upstream-locs (form-locations quickbin-tree upstream))
  (def copy-locs (form-locations quickbin-tree copy-file))
  (def chmod-locs (form-locations quickbin-tree chmod))
  (def patched?
    (and (= 1 (length copy-locs))
         (= 1 (length chmod-locs))
         (when-let [next (zipper/right-skip (first copy-locs))]
           (= chmod (zipper/value next)))))
  (cond
    (and (= 1 (length upstream-locs))
         (empty? copy-locs)
         (empty? chmod-locs))
    (do
      (def replacement
        (honeycut/parse
          (string "# patched by Jeep's prep hook\n"
                  "      (sh/copy-file target output)\n"
                  "      (os/chmod output 8r755)")))
      (def patched-quickbin
        (zipper/root (zipper/replace (first upstream-locs) replacement)))
      (zipper/root (zipper/replace quickbin-loc patched-quickbin)))
    (and (empty? upstream-locs) patched?)
    tree
    (errorf "could not cleanly patch file copying in Spork's quickbin")))

(defn patch-spork []
  (def path (string root "deps" sep "spork" sep "declare-cc.janet"))
  (def source (string (slurp path)))
  (def tree (-> (honeycut/parse source)
                (patch-unused-license)
                (patch-quickbin-copy)))
  (def patched (honeycut/render tree))
  (assert (= patched (honeycut/render (honeycut/parse patched)))
          "patched Spork source did not round-trip cleanly")
  (unless (= source patched)
    (print "patching deps" sep "spork" sep "declare-cc.janet")
    (spit path patched :wb)))
