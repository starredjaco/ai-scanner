require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Scanner
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Disable Active Storage variants since we only store non-image files (ZIP archives)
    config.active_storage.variant_processor = :disabled

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # Ignore lib files/directories that are manually required in initializers
    # (initializers run before Zeitwerk autoloading is ready)
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Allow reading both encrypted and unencrypted data. Set to false once you've
    # confirmed your existing data has been migrated to encrypted format.
    config.active_record.encryption.support_unencrypted_data = true

    # Read credentials from a path, e.g. one from a PersistentVolume
    if ENV["RAILS_CREDENTIALS_PATH"]
      config.credentials.content_path = ENV["RAILS_CREDENTIALS_PATH"]
    end

    if ENV["RAILS_KEY_PATH"]
      config.credentials.key_path = ENV["RAILS_KEY_PATH"]
    end
  end
end
