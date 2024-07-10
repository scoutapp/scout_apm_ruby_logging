# frozen_string_literal: true

require 'logger'

require_relative './formatter'
require_relative './logger'

module ScoutApm
  module Logging
    module Loggers
      # Swaps in our logger for the application's logger.
      class Swap
        attr_reader :context, :log_instance, :new_file_logger

        def initialize(context, log_instance)
          @context = context
          @log_instance = log_instance
        end

        def update_logger!
          create_proxy_log_dir!

          # In Rails 7.1, broadcast logger was added which allows sinking to multiple IO devices.
          if defined?(::ActiveSupport::BroadcastLogger) && log_instance.is_a?(::ActiveSupport::BroadcastLogger)
            add_logger_to_broadcast!
          else
            swap_in_proxy_logger!
          end
        end

        def log_location
          new_file_logger.instance_variable_get(:@logdev).filename
        end

        private

        def add_logger_to_broadcast!
          @new_file_logger = create_file_logger
          @new_file_logger.formatter = Loggers::Formatter.new

          log_instance.broadcast_to(new_file_logger)
        end

        def swap_in_proxy_logger! # rubocop:disable Metrics/AbcSize
          proxy_logger = Proxy.new
          # We can use the previous logdev. log_device will continuously call write
          # through the devices until the logdev (@dev) is an IO device other than logdev:
          # https://github.com/ruby/ruby/blob/master/lib/logger/log_device.rb#L42
          # Log device holds the configurations around shifting too.
          original_logdevice = log_instance.instance_variable_get(:@logdev)
          updated_original_logger = ::Logger.new(original_logdevice)
          updated_original_logger.formatter = log_instance.formatter

          @new_file_logger = create_file_logger
          @new_file_logger.formatter = Loggers::Formatter.new

          # First logger needs to be the original logger for the return value of relayed calls.
          proxy_logger.add(updated_original_logger)
          proxy_logger.add(new_file_logger)

          if defined?(::ActiveSupport::Logger) && log_instance.is_a?(::ActiveSupport::Logger)
            Rails.logger = proxy_logger
          elsif defined?(::Sidekiq::Logger) && log_instance.is_a?(::Sidekiq::Logger)
            Sidekiq.configure_server do |config|
              config.logger = proxy_logger
            end
          elsif defined?(::ScoutTestLogger) && log_instance.is_a?(::ScoutTestLogger)
            TestLoggerWrapper.logger = proxy_logger
          end
        end

        def create_file_logger
          Loggers::Logger.new(context, log_instance).create_logger!
        end

        def create_proxy_log_dir!
          Utils.ensure_directory_exists(context.config.value('proxy_log_dir'))
        end
      end
    end
  end
end
