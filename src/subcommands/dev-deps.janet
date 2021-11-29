(import jpm/commands :as jpm/commands)
(import jpm/pm :as jpm/pm)


(defn- cmd-fn [meta opts params]
  (jpm/commands/deps)
  (if-let [deps (meta :jeep/dev-dependencies)]
    (each dep deps
      (jpm/pm/bundle-install dep))
    (do (print "no dev dependencies found") (flush))))


(def config
  {:help "Install dependencies and development dependencies."
   :fn   cmd-fn})
