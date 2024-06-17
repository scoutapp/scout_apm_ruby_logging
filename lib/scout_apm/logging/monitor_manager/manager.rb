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

        determine_configuration_state
      end

      def determine_configuration_state
        monitoring_enabled = context.config.value('monitor_logs')

        if monitoring_enabled
          context.logger.info('Log monitoring enabled')
          create_process
        else
          context.logger.info('Log monitoring disabled')
          remove_processes
        end
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

        process_exists = Utils.check_process_liveliness(process_id.to_i, 'scout_apm_logging_monitor')
        File.delete(context.config.value('monitor_pid_file')) unless process_exists

        process_exists
      end

      def remove_monitor_process # rubocop:disable Metrics/AbcSize
        return unless File.exist? context.config.value('monitor_pid_file')

        process_id = File.read(context.config.value('monitor_pid_file'))
        return if process_id.empty?

        begin
          Process.kill('TERM', process_id.to_i)
        rescue Errno::ENOENT, Errno::ESRCH => e
          context.logger.error("Error occurred while removing monitor process: #{e.message}")
          File.delete(context.config.value('monitor_pid_file'))
        end
      end

      def remove_collector_process # rubocop:disable Metrics/AbcSize
        return unless File.exist? context.config.value('collector_pid_file')

        process_id = File.read(context.config.value('collector_pid_file'))
        return if process_id.empty?

        begin
          Process.kill('TERM', process_id.to_i)
        rescue Errno::ENOENT, Errno::ESRCH => e
          context.logger.error("Error occurred while removing collector process: #{e.message}")
        ensure
          File.delete(context.config.value('collector_pid_file'))
        end
      end

      def remove_data_file
        return unless File.exist? context.config.value('monitor_data_file')

        File.delete(context.config.value('monitor_data_file'))
      end

      # Remove both the monitor and collector processes that we have spawned.
      def remove_processes
        remove_monitor_process
        remove_collector_process
        remove_data_file
      end
    end
  end
end
