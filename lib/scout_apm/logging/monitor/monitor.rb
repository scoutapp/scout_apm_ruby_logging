# frozen_string_literal: true

##
# Launched as a daemon process by the monitor manager at Rails startup.
##

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
      end

      def setup!
        context.config.logger.info('Monitor daemon process started')

        add_exit_handler

        initiate_collector_setup!

        run!
      end

      def run!
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

      # TODO: Handle situtation where monitor daemon exits, and the known health check
      # port is lost.
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

        @context.health_check_port = health_check_port
      end

      def check_collector_health
        collector_health_endpoint = "http://localhost:#{context.health_check_port}/"
        uri = URI(collector_health_endpoint)

        begin
          response = Net::HTTP.get_response(uri)

          unless response.is_a?(Net::HTTPSuccess)
            context.logger.error("Error occurred while checking collector health: #{response.message}")
            initiate_collector_setup!
          end
        rescue StandardError => e
          context.logger.error("Error occurred while checking collector health: #{e.message}")
          initiate_collector_setup!
        end
      end

      def add_exit_handler
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
