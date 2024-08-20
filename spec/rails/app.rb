# https://github.com/rack/rack/pull/1937
begin
  require 'rackup'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

require 'action_controller/railtie'
require 'logger'
require 'scout_apm_logging'

Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new($stdout))

class App < ::Rails::Application
  config.eager_load = false
  config.log_level = :info

  routes.append do
    root to: 'root#index'
  end
end

class RootController < ActionController::Base
  def index
    Rails.logger.warn('Add location log attributes')
    Rails.logger.tagged('TEST').info('Some log')
    Rails.logger.tagged('YIELD') { logger.info('Yield Test') }
    Rails.logger.info('Another Log')
    Rails.logger.debug('Should not be captured')

    puts 'A puts log'

    render plain: Rails.version
  end
end

def initialize_app
  App.initialize!

  if defined?(Rack::Server)
    Rack::Server.start(app: App)
  else
    Rackup::Server.start(app: App)
  end
end
