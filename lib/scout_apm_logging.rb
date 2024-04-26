# frozen_string_literal: true

require 'scout_apm'

require 'scout_apm/logging/monitor_manager'
require 'scout_apm/logging/monitor/monitor'

module ScoutApm
  module Logging
    if defined?(Rails) && defined?(Rails::Railtie)
      class RailTie < ::Rails::Railtie
        initializer "scout_apm_logging.monitor" do
          puts "Setting up ScoutApm::Logging::MonitorManager..."
          ScoutApm::Logging::MonitorManager.setup!
        end
      end
    end
  end
end
