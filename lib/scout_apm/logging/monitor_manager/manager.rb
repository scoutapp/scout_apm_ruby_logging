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

        add_exit_handler!

        determine_configuration_state
      end

      def determine_configuration_state
        monitoring_enabled = context.config.value('logs_monitor')

        if monitoring_enabled
          context.logger.info('Log monitoring enabled')
          create_process

          # Continue to hold the lock until we have written the PID file.
          ensure_monitor_pid_file_exists
        else
          context.logger.info('Log monitoring disabled')
          remove_processes
        end
      end

      # With the use of fileoffsets in the collector, and the persistent queue of already collected logs,
      # we can safely restart the collector. Due to the way fingerprinting of the files works, if the
      # file path switches, but the beginning contents of the file remain the same, the file will be
      # treated as the same file as before.
      # If logs get rotated, the fingerprint changes, and the collector automatically detects this.
      def add_exit_handler!
        # With the use of unicorn and puma worker killer, we want to ensure we only restart (exit and
        # eventually start) the monitor and collector when the main process exits, and not the workers.
        initialized_process_id = Process.pid
        at_exit do
          # Only remove/restart the monitor and collector if we are exiting from an app_server process.
          # We need to wait on this check, as the process command line changes at some point.
          if Utils.current_process_is_app_server? && Process.pid == initialized_process_id
            context.logger.debug('Exiting from app server process. Removing monitor and collector processes.')
            remove_processes
          end
        end
      end

      def create_process
        return if process_exists?

        Utils.ensure_directory_exists(context.config.value('monitor_pid_file'))

        reader, writer = IO.pipe

        gem_directory = File.expand_path('../../../..', __dir__)

        # As we daemonize the process, we will write to the pid file within the process.
        pid = Process.spawn("ruby #{gem_directory}/bin/scout_apm_logging_monitor", in: reader)

        reader.close
        # TODO: Add support for Sinatra.
        writer.puts Rails.root if defined?(Rails)
        writer.close
        # Block until we have spawned the process and forked. This is to ensure
        # we keep the exclusive lock until the process has written the PID file.
        Process.wait(pid)
      end

      private

      def ensure_monitor_pid_file_exists
        start_time = Time.now
        # We don't want to hold up the initial Rails boot time for very long.
        timeout_seconds = 0.1

        # Naive benchmarks show this taking ~0.01 seconds.
        loop do
          if File.exist?(context.config.value('monitor_pid_file'))
            context.logger.debug('Monitor PID file exists. Releasing lock.')
            break
          end

          if Time.now - start_time > timeout_seconds
            context.logger.warn('Unable to verify monitor PID file write. Releasing lock.')
            break
          end

          sleep 0.01
        end
      end

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
          context.logger.error("Error occurred while removing collector process from manager: #{e.message}")
        ensure
          File.delete(context.config.value('collector_pid_file'))
        end
      end

      def remove_data_file
        return unless File.exist? context.config.value('monitor_state_file')

        File.delete(context.config.value('monitor_state_file'))
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
