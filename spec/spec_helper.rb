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

  config.after(:each) do
    RSpec::Mocks.space.reset_all
  end
end
