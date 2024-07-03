# frozen_string_literal: true

require 'scout_apm'

require 'scout_apm/logging/config'
require 'scout_apm/logging/logger'
require 'scout_apm/logging/context'
require 'scout_apm/logging/utils'

require 'scout_apm/logging/monitor_manager/manager'

module ScoutApm
  ## This module is responsible for setting up monitoring of the application's logs.
  module Logging
    if defined?(Rails) && defined?(Rails::Railtie)
      # If we are in a Rails environment, setup the monitor daemon manager.
      class RailTie < ::Rails::Railtie
        initializer 'scout_apm_logging.monitor' do
          def self.attempt_exclusive_lock
            context = ScoutApm::Logging::MonitorManager.instance.context
            lock_file = context.config.value('manager_lock_file')
            Utils.ensure_directory_exists(lock_file)

            begin
              file = File.open(lock_file, File::RDWR | File::CREAT | File::EXCL)
            rescue Errno::EEXIST
              context.logger.debug('Exclusive lock file held, continuing.')
              return
            end

            # Ensure the lock file is deleted when the block completes
            begin
              yield
            ensure
              file.close
              File.delete(lock_file) if File.exist?(lock_file)
            end
          end

          unless Utils.skip_setup?
            attempt_exclusive_lock do
              ScoutApm::Logging::MonitorManager.instance.setup! unless Utils.skip_setup?
            end
          end
        end
      end
    end
  end
end
