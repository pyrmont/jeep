(import example-native :as native)

(defn wrapper
  ``Adds two numbers using the native function.``
  [x y]
  (native/add x y))
