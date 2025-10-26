(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/uninstall :as subcmd)

(def confirmation "Uninstallation completed.\n")

(deftest uninstall-bundle-by-name
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (spit (string syspath h/sep "example.janet") "")
      (def m1 {:name "example"
               :version "1.0.0"
               :files [(string syspath h/sep "example.janet")]})
      (h/make-manifests "_system" m1)
      (def args {:sub {:params {:name ["example"]}}})
      (subcmd/run args)
      (is (not (index-of "example" (bundle/list))))
      (is (== ["bundle"] (sort (os/dir syspath))))))
  (is (string/has-suffix? confirmation out))
  (is (empty? err)))

(deftest uninstall-current-directory
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def m1 {:name "example" :version "1.0.0"})
      (h/make-manifests "_system" m1)
      (def bundle-path (h/make-bundle "." :name "example"))
      (os/cd bundle-path)
      (def args {:sub {:params {}}})
      (subcmd/run args)
      (is (not (index-of "example" (bundle/list))))))
  (is (string/has-suffix? confirmation out))
  (is (empty? err)))

(deftest uninstall-nonexistent-bundle
  (def out @"")
  (def err @"")
  (def error-caught false)
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def args {:sub {:params {:name ["example"]}}})
      (assert-thrown-message "no bundle example installed"
                             (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest uninstall-multiple-bundles
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def syspath (h/make-syspath "."))
      (def m1 {:name "example1" :version "1.0.0"})
      (def m2 {:name "example2" :version "1.0.0"})
      (h/make-manifests "_system" m1 m2)
      (def args {:sub {:params {:name ["example1" "example2"]}}})
      (subcmd/run args)
      (is (not (index-of "bundle1" (bundle/list))))
      (is (not (index-of "bundle2" (bundle/list))))
      (is (== ["bundle"] (sort (os/dir syspath))))))
  (is (string/has-suffix? confirmation out))
  (is (empty? err)))

(run-tests!)
