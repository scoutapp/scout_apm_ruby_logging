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
      attr_accessor :break_loop
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

        Collector::Manager.new(context).setup!

        run!
      end

      def run!
        loop do
          sleep context.config.value('monitor_interval')

          break if @break_loop # useful for testing

          # TODO: Add some sort of delay before first healthcheck.
          # If monitor_interval is too low, we could be checking the collector health before it's even started.
          check_collector_health
        end
      end

      # Only useful for testing.
      def config=(config)
        context.config = config
      end

      # Only useful for testing.
      def stop!
        @break_loop = true
      end

      private

      def check_collector_health # rubocop:disable Metrics/AbcSize
        # TODO: Make this configurable
        uri = URI('http://localhost:13133/')

        begin
          response = Net::HTTP.get_response(uri)

          unless response.is_a?(Net::HTTPSuccess)
            context.logger.error("Error occurred while checking collector health: #{response.message}")
            Collector::Manager.new(context).setup!
          end
        rescue StandardError => e
          context.logger.error("Error occurred while checking collector health: #{e.message}")
          Collector::Manager.new(context).setup!
        end
      end

      def add_exit_handler
        at_exit do
          File.delete(context.config.value('monitor_pid_file'))
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
