# frozen_string_literal: true

require 'scout_apm'

require 'scout_apm/logging/monitor_manager'

module ScoutApm
  ## This module is responsible for setting up monitoring of the application's logs.
  module Logging
    if defined?(Rails) && defined?(Rails::Railtie)
      # If we are in a Rails environment, setup the monitor daemon manager.
      class RailTie < ::Rails::Railtie
        initializer 'scout_apm_logging.monitor' do
          ScoutApm::Logging::MonitorManager.setup!
        end
      end
    end
  end
end
