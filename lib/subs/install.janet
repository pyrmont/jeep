(import ../install)

(def config {:rules [:bundle {:help `A URL or path to a bundle of Janet code.
                                     If no value is provided, defaults to the
                                     current working directory. Multiple bundles
                                     can be separated by spaces.`
                              :splat? true}]
             :info {:about `Installs a bundle of Janet code using the 'install'
                           hook in 'bundle.janet' or 'bundle/init.janet' of the
                           bundle.

                           If a URL or path to a bundle of Janet code is
                           provided, Jeep will (if necessary) download the code
                           and then install it using Janet's built-in
                           'bundle/install' function. If no argument is
                           provided, Jeep will try to install the code in the
                           current working directory.

                           A bundle is installed to the global syspath unless
                           the user runs 'jeep --local install'.`}
             :help "Install a bundle of Janet code."})

(defn run
  [args &opt jeep-config]
  (def repo (get-in args [:sub :params :bundle]))
  (if (nil? repo)
    (install/install "file::." :force-update true :no-deps true)
    (each rep repo (install/install rep :force-update true)))
  (print "Installation complete."))
