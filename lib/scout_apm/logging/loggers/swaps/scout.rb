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
            context.logger.debug('Swapping in Proxy for Test.')
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
            @original_logger = log_instance.clone
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
