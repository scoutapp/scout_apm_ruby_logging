# frozen_string_literal: true

module ScoutApm
  module Logging
    class MonitorManager
      PID_FILE = '/tmp/scout_apm_log_monitor.pid'

      def self.setup!
        create_daemon
      end

      def self.create_daemon
        return if File.exist? PID_FILE

        # TODO: Investigate behavior of orphaned processes and copy on write behavior.
        # Do we get all of the parent's memory? We may want to spawn the daemon.
        child_process = Process.fork do
          ScoutApm::Logging::Monitor.new.run
        end

        File.write(PID_FILE, child_process)

        # TODO: Add exit handlers?
      end
    end
  end
end