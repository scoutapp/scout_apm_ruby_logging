# frozen_string_literal: true

require 'timeout'

require 'scout_apm'

require "rails"
require "action_controller/railtie"
require "action_view/railtie"

# Require after rails, to ensure the railtie is ran
require 'scout_apm_logging'

class TestLoggerWrapper
  class << self
    attr_accessor :logger
  end
end

class ScoutTestLogger < ::Logger
end

RSpec.configure do |config|
  ENV["SCOUT_LOG_FILE_PATH"] = "STDOUT"
  ENV["SCOUT_LOG_LEVEL"] = "debug"
  ENV["SCOUT_COLLECTOR_LOG_LEVEL"] = "info"

  config.after(:each) do
    RSpec::Mocks.space.reset_all
  end
end

# Taken from:
# https://github.com/rails/rails/blob/v7.1.3.2/railties/test/isolation/abstract_unit.rb#L252
def make_basic_app
  @app = Class.new(Rails::Application) do
    def self.name; "RailtiesTestApp"; end
  end
  @app.config.hosts << proc { true }
  @app.config.eager_load = false
  @app.config.session_store :cookie_store, key: "_myapp_session"
  @app.config.active_support.deprecation = :log
  @app.config.log_level = :info
  @app.config.secret_key_base = "b3c631c314c0bbca50c1b2843150fe33"

  yield @app if block_given?
  @app.initialize!

  @app.routes.draw do
    get "/" => "omg#index"
  end

  require "rack/test"
  extend ::Rack::Test::Methods
end

def wait_for_process_with_timeout!(name, timeout_time)
  Timeout::timeout(timeout_time) do
    loop do
      break if `pgrep #{name} --runstates D,R,S`.strip != ""
      sleep 0.1
    end
  end

  sleep 1
end
