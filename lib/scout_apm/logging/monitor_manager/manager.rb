# frozen_string_literal: true

module ScoutApm
  module Logging
    # Manages the creation of the daemon monitor process.
    class MonitorManager
      attr_reader :context

      @@instance = nil

      def self.instance
        @@instance ||= new
      end

      def initialize
        @context = ScoutApm::Logging::Context.new
        context.config = ScoutApm::Logging::Config.with_file(context, context.config.value("config_file"))
      end

      def setup!
        create_process
      end

      def create_process
        return if File.exist? context.config.value("monitor_pid_file")

        gem_directory = File.expand_path('../../../..', __dir__)
        daemon_process = Process.spawn("ruby #{gem_directory}/bin/scout_apm_logging_monitor", pgroup: true)

        File.write(context.config.value("monitor_pid_file"), daemon_process)

        # TODO: Add exit handlers?
      end
    end
  end
end
