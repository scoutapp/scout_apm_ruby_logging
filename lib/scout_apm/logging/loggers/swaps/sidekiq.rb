# frozen_string_literal: true

module ScoutApm
  module Logging
    module Loggers
      module Swaps
        # Swaps in our logger for the Sidekiq logger.
        class Sidekiq
          attr_reader :context

          def self.present?
            defined?(::Sidekiq) && ::Sidekiq.logger
          end

          def initialize(context)
            @context = context
          end

          def update_logger!
            context.logger.debug("Swapping in Proxy for current Sidekiq logger: #{log_instance.class}.")
            swap_in_proxy_logger!

            new_log_location
          end

          private

          def log_instance
            ::Sidekiq.logger
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
            @original_logger = log_instance.clone
          end

          def new_log_location
            new_file_logger.instance_variable_get(:@logdev).filename
          end

          def swap_in_proxy_logger!
            # First logger needs to be the original logger for the return value of relayed calls.
            proxy_logger = Proxy.create_with_loggers(original_logger, new_file_logger)

            ::Sidekiq.configure_server do |config|
              config.logger = proxy_logger
            end
          end
        end
      end
    end
  end
end
