# frozen_string_literal: true

require 'logger'

require_relative './swap'
require_relative './proxy'
require_relative './destination'

module ScoutApm
  module Logging
    module Loggers
      # Will capture the log destinations from the application's loggers.
      class Capture
        attr_reader :context

        # TODO: Add more supported / known loggers.
        KNOWN_LOGGERS = [
          BROADCAST_LOGGER = 'ActiveSupport::BroadcastLogger',
          ACTIVESUPPORT_LOGGER = 'ActiveSupport::Logger',
          SIDEKIG_LOGGER = 'Sidekiq::Logger',
          # Internal logger for testing.
          TEST_LOGGER = 'ScoutTestLogger'
        ].freeze

        def initialize(context)
          @context = context
        end

        def capture_log_locations! # rubocop:disable Metrics/AbcSize
          updated_log_locations << swapped_in_location(Rails.logger) if defined?(Rails)
          updated_log_locations << swapped_in_location(Sidekiq.logger) if defined?(Sidekiq)

          return if are_the_same_monitored_logs?(updated_log_locations)

          context.config.state.add_log_locations!(updated_log_locations)
        end

        private

        def updated_log_locations
          @updated_log_locations ||= Array.new
        end

        def swapped_in_location(log_instance)
          swap = Swap.new(context, log_instance)

          if log_instance.class.to_s == BROADCAST_LOGGER
            swap.add_logger_to_broadcast!
          else
            swap.swap_in_proxy_logger!
          end
        end

        # In Rails 7.1, broadcast logger was added which allows sinking to multiple IO devices.
        def get_log_devices(log_instance)
          # https://github.com/rails/rails/blob/main/activesupport/lib/active_support/logger.rb#L20
          loggers =
            if log_instance.class.to_s == BROADCAST_LOGGER # rubocop:disable Style/ClassEqualityComparison
              log_instance.broadcasts
            else
              [log_instance]
            end

          loggers.map { |logger| logger.instance_variable_get(:@logdev) }
        end

        def get_log_locations(log_devices)
          log_devices.map { |logdev| try(logdev, 'filename') || try(logdev, 'dev') }.compact
        end

        # A minimal recreation of Rails 'try'.
        def try(obj, method)
          obj.public_send(method) if obj.respond_to? method
        end

        # Should we safeguard and sort before comparison?
        def are_the_same_monitored_logs?(updated_log_locations)
          updated_log_locations == context.config.value('monitored_logs')
        end
      end
    end
  end
end
