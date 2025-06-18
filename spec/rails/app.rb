# https://github.com/rack/rack/pull/1937
begin
  require 'rackup'
rescue LoadError # rubocop:disable Lint/SuppressedException
end

require 'action_controller/railtie'
require 'action_cable/engine'
require 'logger'
require 'scout_apm_logging'

Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new($stdout))

class App < ::Rails::Application
  config.eager_load = false
  config.log_level = :info
  config.action_cable.cable = { 'adapter' => 'async' }
  config.action_cable.connection_class = -> { ApplicationCable::Connection }
  config.action_cable.disable_request_forgery_protection = true

  routes.append do
    mount ActionCable.server => '/cable'
    root to: 'root#index'
  end
end

class RootController < ActionController::Base
  def index # rubocop:disable Metrics/AbcSize
    Rails.logger.tagged('TEST').info('Some log')
    Rails.logger.tagged('YIELD') { logger.info('Yield Test') }
    Rails.logger.info('Another Log')
    Rails.logger.debug('Should not be captured')
    Rails.logger.warn('Warn level log')
    Rails.logger.error('Error level log')
    Rails.logger.fatal('Fatal level log')

    render plain: Rails.version
  end
end

module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :id

    def connect
      self.id = SecureRandom.uuid
      logger.info("ActionCable Connected: #{id}")
    end
  end
end

class TestChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'test_channel'
    logger.info 'Subscribed to test_channel'
  end

  def ding(data)
    logger.info "Ding received with data: #{data.inspect}"
    transmit({ dong: "Server response to: '#{data['message']}'" })
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
