# frozen_string_literal: true

module ScoutApm
  module Logging
    module Loggers
      module Swaps
        # Swaps in our logger for the test Scout logger.
        class Scout
          attr_reader :context

          def self.present?
            defined?(::TestLoggerWrapper) && ::TestLoggerWrapper.logger
          end

          def initialize(context)
            @context = context
          end

          def update_logger!
            swap_in_proxy_logger!

            new_log_location
          end

          private

          def log_instance
            ::TestLoggerWrapper.logger
          end

          def new_file_logger
            @new_file_logger ||= Loggers::Logger.new(context, log_instance).create_logger!
          end

          # Eseentially creates the original logger.
          def original_logger
            # We can use the previous logdev. log_device will continuously call write
            # through the devices until the logdev (@dev) is an IO device other than logdev:
            # https://github.com/ruby/ruby/blob/master/lib/logger/log_device.rb#L42
            # Log device holds the configurations around shifting too.
            original_logdevice = log_instance.instance_variable_get(:@logdev)

            ::Logger.new(original_logdevice).tap do |logger|
              logger.level = log_instance.level
              logger.formatter = log_instance.formatter
            end
          end

          def new_log_location
            new_file_logger.instance_variable_get(:@logdev).filename
          end

          def swap_in_proxy_logger!
            # First logger needs to be the original logger for the return value of relayed calls.
            proxy_logger = Proxy.create_with_loggers(original_logger, new_file_logger)

            ::TestLoggerWrapper.logger = proxy_logger
          end
        end
      end
    end
  end
end
