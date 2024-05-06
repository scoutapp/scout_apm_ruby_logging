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
        context.config = ScoutApm::Logging::Config.with_file(context, context.config.value('config_file'))
      end

      def setup!
        create_process
      end

      # TODO: Re-evaluate this method.
      def create_process # rubocop:disable Metrics/AbcSize
        # TODO: Do an actual check that the process actually exists.
        return if File.exist? context.config.value('monitor_pid_file')

        ScoutApm::Logging::Utils.ensure_directory_exists(context.config.value('monitor_pid_file'))

        reader, writer = IO.pipe

        gem_directory = File.expand_path('../../../..', __dir__)
        daemon_process = Process.spawn("ruby #{gem_directory}/bin/scout_apm_logging_monitor", pgroup: true, in: reader)

        File.write(context.config.value('monitor_pid_file'), daemon_process)

        reader.close
        writer.puts Rails.root if defined?(Rails)
        writer.puts Rails.env if defined?(Rails)
        writer.close

        # TODO: Add exit handlers?
      end
    end
  end
end
