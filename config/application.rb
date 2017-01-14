require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module BioPortal
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Load BioPortal-specific configuration options
    config.bp = config_for(:bioportal)

    # Serve error pages from the Rails app itself, instead of using static error pages in /public.
    config.exceptions_app = self.routes
  end
end
