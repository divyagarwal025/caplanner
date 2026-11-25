# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "chartkick", to: "chartkick.js" # @5.0.1
pin "chart.js" # @4.6.1
# chart.js 4.6.1's ESM dist is code-split; this is its internal chunk (was the
# unresolved "../_/BDnc5-Gm.js" that 404'd and left every chart on "Loading…").
pin "chart.js-internal", to: "chart.js-internal.js"
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
