// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "turbo_frame_history_fix" // Must be after turbo-rails to patch Turbo
import "channels/consumer" // Required for Turbo Streams over ActionCable
import "controllers"

import "set_timezone_cookie";
