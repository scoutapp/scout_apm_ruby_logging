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
              context.logger.debug('Rails Broadcast logger detected. Adding new logger to broadcast.')
              add_logger_to_broadcast!
            else
              context.logger.debug('Swapping in Proxy for Rails.')
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

          def original_logger
            @original_logger = log_instance.clone.tap do |logger|
              if ::Rails.env.development? && $stdout.tty? && $stderr.tty?
                next if ::ActiveSupport::Logger.respond_to?(:logger_outputs_to?) && ::ActiveSupport::Logger.logger_outputs_to?(
                  logger, $stdout, $stderr
                )

                logger.extend(ActiveSupport::Logger.broadcast(::ActiveSupport::Logger.new($stdout)))
              end
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
            proxy_logger.extend ::ActiveSupport::TaggedLogging if log_instance.respond_to?(:tagged)

            ::Rails.logger = proxy_logger

            # We also need to swap some of the Rails railtie loggers.
            ::ActiveRecord::Base.logger = proxy_logger if defined?(::ActiveRecord::Base)
            ::ActionController::Base.logger = proxy_logger if defined?(::ActionController::Base)
            ::ActiveJob::Base.logger = proxy_logger if defined?(::ActiveJob::Base)
          end
        end
      end
    end
  end
end
