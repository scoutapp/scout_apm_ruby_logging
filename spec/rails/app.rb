# https://github.com/rack/rack/pull/1937
begin
  require 'rackup'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

require 'benchmark/ips'
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
    Benchmark.ips do |b|
      b.report('patched_warn') do
        Rails.logger.warn_first('Add location log attributes')
      end
      b.report('patched_warn_2') do
        Rails.logger.warn_two('Add location log attributes')
      end
      b.report('patched_warn_3') do
        Rails.logger.warn_three('Add location log attributes')
      end
      b.report('patched_warn_4') do
        Rails.logger.warn_four('Add location log attributes')
      end
      b.report('original_warn') do
        Rails.logger.original_warn('Add location log attributes')
      end
      b.compare!
    end

    Rails.logger.tagged('TEST').info('Some log')
    Rails.logger.tagged('YIELD') { logger.info('Yield Test') }
    Rails.logger.info('Another Log')
    Rails.logger.debug('Should not be captured')

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
