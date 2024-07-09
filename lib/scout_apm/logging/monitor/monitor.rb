# frozen_string_literal: true

##
# Launched as a daemon process by the monitor manager at Rails startup.
##
require 'json'

require 'scout_apm'

require_relative '../logger'
require_relative '../context'
require_relative '../config'
require_relative '../utils'
require_relative '../state'
require_relative './collector/manager'

module ScoutApm
  module Logging
    # Entry point for the monitor daemon process.
    class Monitor
      attr_reader :context
      attr_accessor :latest_state_sha

      @@instance = nil

      def self.instance
        @@instance ||= new
      end

      def initialize
        @context = Context.new

        context.application_root = $stdin.gets&.chomp

        # Load in the dynamic and state based config settings.
        context.config = Config.with_file(context, determine_scout_config_filepath)

        @latest_state_sha = get_state_file_sha

        daemonize_process!
      end

      def setup!
        context.config.logger.info('Monitor daemon process started')

        add_exit_handler!

        unless has_logs_to_monitor?
          context.config.logger.warn('No logs are set to be monitored. Please set the `monitored_logs` config setting. Exiting.')
          return
        end

        initiate_collector_setup! unless has_previous_collector_setup?

        run!
      end

      def run!
        # Prevent the monitor from checking the collector health before it's fully started.
        # Having this be configurable is useful for testing.
        sleep context.config.value('delay_first_healthcheck')

        loop do
          sleep context.config.value('monitor_interval')

          check_collector_health

          check_state_change
        end
      end

      # Only useful for testing.
      def config=(config)
        context.config = config
      end

      private

      def daemonize_process!
        # Similar to that of Process.daemon, but we want to keep the dir, STDOUT and STDERR.
        exit if fork
        Process.setsid
        exit if fork
        $stdin.reopen '/dev/null'

        File.write(context.config.value('monitor_pid_file'), Process.pid)
      end

      def has_logs_to_monitor?
        context.config.value('monitored_logs').any?
      end

      def has_previous_collector_setup?
        return false unless context.config.value('health_check_port') != 0

        healthy_response = request_health_check_port("http://localhost:#{context.config.value('health_check_port')}/")

        if healthy_response
          context.logger.info("Collector already setup on port #{context.config.value('health_check_port')}")
        else
          context.logger.info('Setting up new collector')
        end

        healthy_response
      end

      def initiate_collector_setup!
        set_health_check_port!

        Collector::Manager.new(context).setup!
      end

      def is_port_available?(port)
        s = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        sa = Socket.sockaddr_in(port, '127.0.0.1')

        begin
          s.connect_nonblock(sa)
        rescue Errno::EINPROGRESS
          if IO.select(nil, [s], nil, 1)
            begin
              s.connect_nonblock(sa)
            rescue Errno::EISCONN
              return false
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
              return true
            end
          end
        end

        true
      end

      def set_health_check_port!
        health_check_port = 13_133
        until is_port_available?(health_check_port)
          sleep 1
          health_check_port += 1
        end

        Config::ConfigDynamic.set_value('health_check_port', health_check_port)
        context.config.state.flush_state!
      end

      def request_health_check_port(endpoint)
        uri = URI(endpoint)

        begin
          response = Net::HTTP.get_response(uri)

          unless response.is_a?(Net::HTTPSuccess)
            context.logger.error("Error occurred while checking collector health: #{response.message}")
            return false
          end
        rescue StandardError => e
          context.logger.error("Error occurred while checking collector health: #{e.message}")
          return false
        end

        true
      end

      def check_collector_health
        context.logger.debug('Checking collector health')
        collector_health_endpoint = "http://localhost:#{context.config.value('health_check_port')}/"

        healthy_response = request_health_check_port(collector_health_endpoint)

        initiate_collector_setup! unless healthy_response
      end

      def remove_collector_process # rubocop:disable Metrics/AbcSize
        return unless File.exist? context.config.value('collector_pid_file')

        process_id = File.read(context.config.value('collector_pid_file'))
        return if process_id.empty?

        begin
          Process.kill('TERM', process_id.to_i)
        rescue Errno::ENOENT, Errno::ESRCH => e
          context.logger.error("Error occurred while removing collector process from monitor: #{e.message}")
        ensure
          File.delete(context.config.value('collector_pid_file'))
        end
      end

      def check_state_change
        current_sha = get_state_file_sha

        return if current_sha == latest_state_sha

        remove_collector_process
        initiate_collector_setup!
      end

      def add_exit_handler!
        at_exit do
          # There may not be a file to delete, as the monitor manager ensures cleaning it up when monitoring is disabled.
          File.delete(context.config.value('monitor_pid_file')) if File.exist?(context.config.value('monitor_pid_file'))
        end
      end

      def get_state_file_sha
        return nil unless File.exist?(context.config.value('monitor_state_file'))

        `sha256sum #{context.config.value('monitor_state_file')}`.split(' ').first
      end

      def determine_scout_config_filepath
        "#{context.application_root}/config/scout_apm.yml"
      end
    end
  end
end
