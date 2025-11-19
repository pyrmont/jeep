(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/build :as subcmd)

(def confirmation "Build completed.\n")

(deftest build-creates-build-directory
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-build"}
        ```)
      (spit "info.jdn" info-file)
      (spit "bundle.janet" "")
      (def args {:sub {:params {:args []}}})
      (subcmd/run args)
      (is (= :directory (os/stat "_build" :mode)))
      (is (== confirmation out))
      (is (empty? err)))))

(deftest build-with-no-bundle-script
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-no-script"}
        ```)
      (spit "info.jdn" info-file)
      (def args {:sub {:params {:args []}}})
      (def msg "error loading bundle script")
      (assert-thrown-message msg (subcmd/run args))
      (is (= :directory (os/stat "_build" :mode)))))
  (is (empty? out))
  (is (empty? err)))

(deftest build-with-build-function
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-with-build"}
        ```)
      (spit "info.jdn" info-file)
      (def build-script
        ```
        (defn build
          [manifest & args]
          (print "Args: " (string/join args " ")))
        ```)
      (spit "bundle.janet" build-script)
      (def args {:sub {:params {:args []}}})
      (subcmd/run args)
      (is (= :directory (os/stat "_build" :mode)))))
  (is (== (string "Args: \n" confirmation) out))
  (is (empty? err)))

(deftest build-with-arguments
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-with-args"}
        ```)
      (spit "info.jdn" info-file)
      (def build-script
        ```
        (defn build
          [manifest & args]
          (print "Args: " (string/join args ", ")))
        ```)
      (spit "bundle.janet" build-script)
      (def args {:sub {:params {:args ["foo" "bar" "baz"]}}})
      (subcmd/run args)
      (is (= :directory (os/stat "_build" :mode)))))
  (is (== (string "Args: foo, bar, baz\n" confirmation) out))
  (is (empty? err)))

(deftest build-preserves-existing-build-directory
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-preserve"}
        ```)
      (spit "info.jdn" info-file)
      (spit "bundle.janet" "")
      (os/mkdir "_build")
      (spit "_build/existing.txt" "existing content")
      (def args {:sub {:params {:args []}}})
      (subcmd/run args)
      (is (= :directory (os/stat "_build" :mode)))
      (is (= :file (os/stat "_build/existing.txt" :mode)))
      (is (== "existing content" (slurp "_build/existing.txt")))
      (is (== confirmation out))
      (is (empty? err)))))

(deftest build-with-bundle-script-error
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-error"}
        ```)
      (spit "info.jdn" info-file)
      (def build-script
        ```
        (defn build
          [& args]
          (error "Build failed!"))
        ```)
      (spit "bundle.janet" build-script)
      (def args {:sub {:params {:args []}}})
      (assert-thrown-message "Build failed!"
                             (subcmd/run args)))))

(run-tests!)
