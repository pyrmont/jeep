(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/list :as subcmd)

(def confirm-begin "Installed bundles:\n")
(def confirm-end "Listing completed.\n")

(defn- listing-ok? [out]
  (def needles ["System:\n"
                "  version:"
                "  platform:"
                "  syspath:"
                "Environment:\n"
                "  JANET_PATH:"
                "  jeep:"])
  (var counter 0)
  (var begin 0)
  (each needle needles 
    (def pos (string/find needle out begin))
    (if (nil? pos)
      (break))
    (set begin pos)
    (++ counter))
  (= (length needles) counter))

(deftest list-empty-system
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (setdyn :syspath d)
      (def args {:sub {:params {}
                       :opts {}}})
      (subcmd/run args)))
  (is (string/has-prefix? confirm-begin out))
  (is (string/find "No bundles installed\n" out (length confirm-begin)))
  (is (listing-ok? out))
  (is (string/has-suffix? confirm-end out))
  (is (empty? err)))

(deftest list-with-bundles
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (setdyn :syspath d)
      (def m1 {:name "bundle1" :version "1.0.0"})
      (def m2 {:name "bundle2" :version "37-foobar"})
      (h/make-manifests "." m1 m2)
      (def args {:sub {:params {}
                       :opts {}}})
      (subcmd/run args)))
  (def from (length confirm-begin))
  (is (string/has-prefix? confirm-begin out))
  (is (string/find "bundle1 (1.0.0)\n" out from))
  (is (string/find "bundle2 (37-foobar)\n" out from))
  (is (listing-ok? out))
  (is (string/has-suffix? confirm-end out))
  (is (empty? err)))

(deftest list-with-no-legacy-flag
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (setdyn :syspath d)
      (def args {:sub {:params {}
                       :opts {"no-legacy" true}}})
      (subcmd/run args)))
  (is (string/has-prefix? confirm-begin out))
  (is (string/find "No bundles installed\n" out (length confirm-begin)))
  (is (listing-ok? out))
  (is (string/has-suffix? confirm-end out))
  (is (empty? err)))

(run-tests!)
