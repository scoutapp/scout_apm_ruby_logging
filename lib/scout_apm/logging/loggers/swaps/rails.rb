# frozen_string_literal: true

module ScoutApm
  module Logging
    module Loggers
      module Swaps
        # Swaps in our logger for the Rails logger.
        class Rails
          attr_reader :context

          def self.present?
            defined?(::Rails) && ::Rails.logger
          end

          def initialize(context)
            @context = context
          end

          def update_logger!
            # In Rails 7.1, broadcast logger was added which allows sinking to multiple IO devices.
            if defined?(::ActiveSupport::BroadcastLogger) && log_instance.is_a?(::ActiveSupport::BroadcastLogger)
              add_logger_to_broadcast!
            else
              swap_in_proxy_logger!
            end

            new_log_location
          end

          private

          def log_instance
            ::Rails.logger
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
              logger.formatter = log_instance.formatter
            end
          end

          def new_log_location
            new_file_logger.instance_variable_get(:@logdev).filename
          end

          def add_logger_to_broadcast!
            log_instance.broadcast_to(new_file_logger)
          end

          def swap_in_proxy_logger!
            # First logger needs to be the original logger for the return value of relayed calls.
            proxy_logger = Proxy.create_with_loggers(original_logger, new_file_logger)

            ::Rails.logger = proxy_logger
          end
        end
      end
    end
  end
end
