(use ../deps/testament)
(import ../res/helpers/util :as h)

(import ../lib/subs/install :as subcmd)

(def confirmation "Installation completed.\n")

(deftest install-current-directory
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (os/mkdir "_system")
      (setdyn :syspath (os/realpath "_system"))
      (def path (h/make-bundle "." :name "test-install"))
      (os/cd path)
      (def args {:sub {:params {:bundle nil}
                       :opts {}}})
      (subcmd/run args)))
  (def expect
    (string "no files installed, is this a valid bundle?\n"
            "installed test-install\n"
            "Installation completed.\n"))
  (is (== expect out))
  (is (empty? err)))

(deftest install-with-replace-flag
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (os/mkdir "_system")
      (setdyn :syspath (os/realpath "_system"))
      (def path (h/make-bundle "." :name "test-replace"))
      (os/cd path)
      (def args {:sub {:params {:bundle nil}
                       :opts {"replace" true}}})
      (subcmd/run args)))
  (def expect
    (string "no files installed, is this a valid bundle?\n"
            "installed test-replace\n"
            "Installation completed.\n"))
  (is (== expect out))
  (is (empty? err)))

(deftest install-bundle-by-path
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (os/mkdir "_system")
      (setdyn :syspath (os/realpath "_system"))
      (os/cd ".")
      (def bundle (string "file::" (h/make-bundle "." :name "bundle")))
      (def args {:sub {:params {:bundle [bundle]}
                       :opts {}}})
      (subcmd/run args)))
  (def expect
    (string "no files installed, is this a valid bundle?\n"
            "installed bundle\n"
            "Installation completed.\n"))
  (is (== expect out))
  (is (empty? err)))

(deftest install-multiple-bundles
  (def out @"")
  (def err @"")
  (with-dyns [:out out
              :err err]
    (h/in-dir d
      (os/mkdir "_system")
      (setdyn :syspath (os/realpath "_system"))
      (os/cd ".")
      (def bundle1 (string "file::" (h/make-bundle "." :name "bundle1")))
      (def bundle2 (string "file::" (h/make-bundle "." :name "bundle2")))
      (def args {:sub {:params {:bundle [bundle1 bundle2]}
                       :opts {}}})
      (subcmd/run args)
      ))
  (def expect
    (string "no files installed, is this a valid bundle?\n"
            "installed bundle1\n"
            "no files installed, is this a valid bundle?\n"
            "installed bundle2\n"
            "Installation completed.\n"))
  (is (== expect out))
  (is (empty? err)))

(run-tests!)
