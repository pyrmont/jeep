(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/clean :as subcmd)

(def confirm-cleaned "Cleaning completed.\n")
(def confirm-nothing "No files to clean.\n")

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
      (def msg "failed to load bundle script")
      (assert-thrown-message msg (subcmd/run args))))
  (is (empty? out))
  (is (empty? err)))

(deftest clean-with-no-directories
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-clean"}
        ```)
      (spit "info.jdn" info-file)
      (spit "bundle.janet" "")
      (def args {:sub {:opts {}}})
      (subcmd/run args)))
  (is (== confirm-nothing out))
  (is (empty? err)))

(deftest clean-removes-build-directory-contents
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-clean"}
        ```)
      (spit "info.jdn" info-file)
      (spit "bundle.janet" "")
      (os/mkdir "_build")
      (spit "_build/file1.txt" "content1")
      (spit "_build/file2.txt" "content2")
      (def args {:sub {:opts {}}})
      (subcmd/run args)
      (is (= :directory (os/stat "_build" :mode)))
      (is (empty? (os/dir "_build")))))
  (is (== confirm-cleaned out))
  (is (empty? err)))

(deftest clean-with-build-flag-removes-entire-directory
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-clean"}
        ```)
      (spit "info.jdn" info-file)
      (spit "bundle.janet" "")
      (os/mkdir "_build")
      (spit "_build/file.txt" "content")
      (def args {:sub {:opts {"build" true}}})
      (subcmd/run args)
      (is (nil? (os/stat "_build" :mode)))))
  (is (== confirm-cleaned out))
  (is (empty? err)))

(deftest clean-with-system-flag-removes-system-directory
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-clean"}
        ```)
      (spit "info.jdn" info-file)
      (spit "bundle.janet" "")
      (os/mkdir "_system")
      (spit "_system/file.txt" "content")
      (def args {:sub {:opts {"system" true}}})
      (subcmd/run args)
      (is (nil? (os/stat "_system" :mode)))))
  (is (== confirm-cleaned out))
  (is (empty? err)))

(deftest clean-with-both-flags
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-clean"}
        ```)
      (spit "info.jdn" info-file)
      (spit "bundle.janet" "")
      (os/mkdir "_build")
      (spit "_build/file1.txt" "content1")
      (os/mkdir "_system")
      (spit "_system/file2.txt" "content2")
      (def args {:sub {:opts {"build" true "system" true}}})
      (subcmd/run args)
      (is (nil? (os/stat "_build" :mode)))
      (is (nil? (os/stat "_system" :mode)))))
  (is (== confirm-cleaned out))
  (is (empty? err)))

(deftest clean-with-bundle-script-hook
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-clean-hook"}
        ```)
      (spit "info.jdn" info-file)
      (def bundle-content
        ```
        (defn clean
          []
          (print "Custom cleaning"))
        ```)
      (spit "bundle.janet" bundle-content)
      (def args {:sub {:opts {}}})
      (subcmd/run args)))
  (is (== "Custom cleaning\nCleaning completed.\n" out))
  (is (empty? err)))

(deftest clean-preserves-build-directory-when-only-removing-contents
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (def info-file
        ```
        {:name "test-clean"}
        ```)
      (spit "info.jdn" info-file)
      (spit "bundle.janet" "")
      (os/mkdir "_build")
      (os/mkdir "_build/subdir")
      (spit "_build/subdir/file.txt" "content")
      (def args {:sub {:opts {}}})
      (subcmd/run args)
      (is (= :directory (os/stat "_build" :mode)))
      (is (empty? (os/dir "_build")))))
  (is (== confirm-cleaned out))
  (is (empty? err)))

(run-tests!)
