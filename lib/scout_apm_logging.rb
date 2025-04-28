# frozen_string_literal: true

require 'scout_apm'

require 'scout_apm/logging/config'
require 'scout_apm/logging/logger'
require 'scout_apm/logging/context'
require 'scout_apm/logging/utils'
require 'scout_apm/logging/loggers/capture'

module ScoutApm
  ## This module is responsible for setting up monitoring of the application's logs.
  module Logging
    if defined?(Rails) && defined?(Rails::Railtie)
      # If we are in a Rails environment, setup the monitor daemon manager.
      class RailTie < ::Rails::Railtie
        initializer 'scout_apm_logging.monitor', after: :initialize_logger, before: :initialize_cache do
          context = ScoutApm::Logging::Context.instance

          Loggers::Capture.new(context).setup!
        end
      end
    end
  end
end
