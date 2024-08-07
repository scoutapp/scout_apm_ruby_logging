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

def wait_for_process_with_timeout!(name, timeout_time)
  Timeout::timeout(timeout_time) do
    loop do
      break if `pgrep #{name} --runstates D,R,S`.strip != ""
      sleep 0.1
    end
  end

  sleep 1
end
