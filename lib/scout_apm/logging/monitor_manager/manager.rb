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
        @context = Context.new
        context.config = Config.with_file(context, context.config.value('config_file'))
      end

      def setup!
        context.config.log_settings(context.logger)
        context.logger.info('Setting up monitor daemon process')

        create_process
      end

      def create_process # rubocop:disable Metrics/AbcSize
        return if process_exists?

        Utils.ensure_directory_exists(context.config.value('monitor_pid_file'))

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

      private

      def process_exists?
        return false unless File.exist? context.config.value('monitor_pid_file')

        process_id = File.read(context.config.value('monitor_pid_file'))
        return false if process_id.empty?

        Utils.check_process_livelyness(process_id.to_i, 'scout_apm_logging_monitor')
      end
    end
  end
end
