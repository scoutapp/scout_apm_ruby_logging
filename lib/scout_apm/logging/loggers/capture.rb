# frozen_string_literal: true

require 'logger'

require_relative './swap'
require_relative './proxy'

module ScoutApm
  module Logging
    module Loggers
      # Will capture the log destinations from the application's loggers.
      class Capture
        attr_reader :context

        def initialize(context)
          @context = context
        end

        def capture_log_locations! # rubocop:disable Metrics/AbcSize
          logger_instances << Rails.logger if defined?(Rails)
          logger_instances << Sidekiq.logger if defined?(Sidekiq)
          logger_instances << ObjectSpace.each_object(::ScoutTestLogger).to_a if defined?(::ScoutTestLogger)

          # Swap in our logger for each logger instance, in conjunction with the original class.
          updated_log_locations = logger_instances.compact.flatten.map do |logger|
            swapped_in_location(logger)
          end

          context.config.state.add_log_locations!(updated_log_locations)
        end

        private

        def logger_instances
          @logger_instances ||= []
        end

        def swapped_in_location(log_instance)
          swap = Swap.new(context, log_instance)
          swap.update_logger!
          swap.log_location
        end
      end
    end
  end
end
