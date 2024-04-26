# frozen_string_literal: true

##
# Launched as a daemon process by the monitor manager and Rails startup.
##

require_relative '../monitor_manager'

module ScoutApm
  module Logging
    # Entry point for the monitor daemon process.
    class Monitor
      def run
        add_exit_handler

        loop do
          sleep 1
          puts 'Running...'
        end
      end

      private

      def add_exit_handler
        at_exit do
          File.delete(ScoutApm::Logging::MonitorManager::PID_FILE)
        end
      end
    end
  end
end
