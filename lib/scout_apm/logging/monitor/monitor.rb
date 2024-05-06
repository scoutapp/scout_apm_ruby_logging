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
        @context = ScoutApm::Logging::Context.new
        @context.environment_root = STDIN.gets.chomp
        @context.environment_type = STDIN.gets.chomp
        ScoutApm::Logging::Config::ConfigDynamic.set_value('monitored_logs', [assumed_rails_log_path])
        context.config = ScoutApm::Logging::Config.with_file(context, determine_scout_config_filepath)
      end

      def setup!
        add_exit_handler

        ScoutApm::Logging::Collector::Manager.new(context).setup!

        run!
      end

      def run!
        loop do
          sleep 1
          puts 'Running...'
        end
      end

      private

      def add_exit_handler
        at_exit do
          File.delete(context.config.value('monitor_pid_file'))
        end
      end

      def determine_scout_config_filepath
        context.environment_root + '/config/scout_apm.yml'
      end

      def assumed_rails_log_path
        environment_type = context.environment_type
        context.environment_root + "/logs/#{environment_type}.log"
      end
    end
  end
end
