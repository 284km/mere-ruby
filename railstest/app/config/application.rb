require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)
module RailsSmoke
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false
    config.secret_key_base = "rails-smoke-public-test-fixture-" * 4
    config.hosts = ["www.example.com", "127.0.0.1", "localhost"]
    config.logger = Logger.new($stderr)
    config.log_level = :warn
    config.active_storage.service = :test
    config.active_storage.variant_processor = :disabled
    config.active_job.queue_adapter = :test
  end
end
