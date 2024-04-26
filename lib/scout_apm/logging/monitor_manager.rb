# frozen_string_literal: true

module ScoutApm
  module Logging
    class MonitorManager
      PID_FILE = '/tmp/scout_apm_log_monitor.pid'

      def self.setup!
        create_process
      end

      def self.create_process
        return if File.exist? PID_FILE

        gem_directory = File.expand_path('../../..', __dir__)
        
        Process.spawn("ruby #{gem_directory}/bin/scout_apm_logging_monitor &")
        daemon_process = `pgrep -f scout_apm_logging_monitor`.to_i

        File.write(PID_FILE, daemon_process)

        # TODO: Add exit handlers?
      end
    end
  end
end