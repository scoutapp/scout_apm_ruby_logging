# frozen_string_literal: true

require 'logger'

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
          logger_instances = []

          logger_instances << Rails.logger if defined?(Rails)
          logger_instances << Sidekiq.logger if defined?(Sidekiq)
          logger_instances << ObjectSpace.each_object(::ScoutTestLogger).to_a if defined?(::ScoutTestLogger)
          logger_instances.flatten!

          updated_log_locations = []
          logger_instances.each do |log_instance|
            log_devices = get_log_devices(log_instance)
            log_locations = get_log_location(log_devices)

            log_locations.each do |location|
              # TODO: Add a proxy logger if we are logging to STDOUT
              next if location == $stdout

              updated_log_locations << location
            end
          end

          context.config.state.add_log_locations!(updated_log_locations)
        end

        private

        # In Rails 7.1, broadcast logger was added which allows sinking to multiple IO devices.
        def get_log_devices(log_instance)
          # https://github.com/rails/rails/blob/main/activesupport/lib/active_support/logger.rb#L20
          loggers =
            if defined?(ActiveSupport::BroadcastLogger) && log_instance.is_a?(ActiveSupport::BroadcastLogger)
              log_instance.broadcasts
            else
              [log_instance]
            end

          loggers.map { |logger| logger.instance_variable_get(:@logdev) }
        end

        def get_log_location(log_devices)
          locations = log_devices.map do |logdev|
            if logdev.respond_to?(:filename)
              puts logdev.filename
              logdev.filename
            elsif logdev.respond_to?(:dev)
              device = logdev.dev
              device.respond_to?(:path) ? device.path : device
            end
          end

          locations.compact
        end
      end
    end
  end
end
