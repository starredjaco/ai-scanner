# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/actioncable", to: "actioncable.esm.js" # from actioncable gem
pin_all_from "app/javascript/controllers", under: "controllers", preload: false
pin "channels/consumer", to: "channels/consumer.js"
pin "graphs/common", to: "graphs/common.js", preload: false
pin "config/chartConfig", to: "config/chartConfig.js", preload: false
pin "utils", to: "utils.js", preload: false
pin "set_timezone_cookie"
pin "turbo_frame_history_fix"

# Custom admin assets
pin "flowbite", preload: true
