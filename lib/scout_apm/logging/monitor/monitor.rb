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
require_relative './collector/manager'

module ScoutApm
  module Logging
    # Entry point for the monitor daemon process.
    class Monitor
      attr_reader :context

      @@instance = nil

      def self.instance
        @@instance ||= new
      end

      def initialize
        @context = Context.new

        @context.application_root = $stdin.gets&.chomp
        @context.application_env = $stdin.gets&.chomp

        Config::ConfigDynamic.set_value('monitored_logs', [assumed_rails_log_path])
        context.config = Config.with_file(context, determine_scout_config_filepath)

        check_process_then_daemonize!
      end

      def setup!
        context.config.logger.info('Monitor daemon process started')

        load_previous_monitor_data!

        add_exit_handler!

        initiate_collector_setup! unless has_previous_collector_setup?

        run!
      end

      def run!
        # Prevent the monitor from checking the collector health before it's fully started.
        # Having this be configurable is useful for testing.
        sleep context.config.value('delay_first_healthcheck')

        loop do
          sleep context.config.value('monitor_interval')

          # TODO: Add some sort of delay before first healthcheck.
          # If monitor_interval is too low, we could be checking the collector health before it's even started.
          check_collector_health
        end
      end

      # Only useful for testing.
      def config=(config)
        context.config = config
      end

      private

      def exit_if_we_arent_only_monitor
        exit if Utils.process_of_same_name_count?($PROGRAM_NAME) > 1
      end

      def check_process_then_daemonize!
        # Similar to that of Process.daemon, but we want to keep the dir, STDOUT and STDERR.
        # Relevant: https://workingwithruby.com/wwup/daemons/
        exit if fork
        Process.setsid
        exit if fork
        $stdin.reopen '/dev/null'

        exit_if_we_arent_only_monitor

        File.write(context.config.value('monitor_pid_file'), Process.pid)
      end

      # If we have a previous monitor data file, load it into the context.
      def load_previous_monitor_data!
        return unless File.exist?(context.config.value('monitor_data_file'))

        file_contents = File.read(context.config.value('monitor_data_file'))
        data = JSON.parse(file_contents)
        context.stored_data = data
      end

      def has_previous_collector_setup? # rubocop:disable Metrics/AbcSize
        return false unless context.stored_data&.key?('health_check_port')

        healthy_response = request_health_check_port("http://localhost:#{context.stored_data['health_check_port']}/")

        if healthy_response
          context.health_check_port = context.stored_data['health_check_port']
          context.logger.info("Collector already setup on port #{context.stored_data['health_check_port']}")
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

        # TODO: If we start to use the monitor data file more, we should move the management of the data file
        # into its own class.
        data = { health_check_port: health_check_port }
        File.write(context.config.value('monitor_data_file'), JSON.pretty_generate(data))

        context.health_check_port = health_check_port
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
        collector_health_endpoint = "http://localhost:#{context.health_check_port}/"

        healthy_response = request_health_check_port(collector_health_endpoint)

        initiate_collector_setup! unless healthy_response
      end

      def add_exit_handler!
        at_exit do
          # There may not be a file to delete, as the monitor manager ensures cleaning it up when monitoring is disabled.
          File.delete(context.config.value('monitor_pid_file')) if File.exist?(context.config.value('monitor_pid_file'))
        end
      end

      def determine_scout_config_filepath
        "#{context.application_root}/config/scout_apm.yml"
      end

      def assumed_rails_log_path
        context.application_root + "/log/#{context.application_env}.log"
      end
    end
  end
end
