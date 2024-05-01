# frozen_string_literal: true

##
# Launched as a daemon process by the monitor manager at Rails startup.
##

require 'scout_apm'

require_relative '../logger'
require_relative '../context'
require_relative '../config'

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
        context.config = ScoutApm::Logging::Config.with_file(context, context.config.value('config_file'))
      end

      def setup!
        add_exit_handler

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
    end
  end
end
