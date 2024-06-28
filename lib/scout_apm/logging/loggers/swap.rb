require 'logger'

module ScoutApm
  module Logging
    module Loggers
      class Swap
        attr_reader :context
        attr_reader :log_instance

        def initialize(context, log_instance)
          @context = context
          @log_instance = log_instance
        end

        def add_logger_to_broadcast!
          new_file_logger = create_destination_logger
          log_instance.broadcast_to(new_file_logger)

          path_of_logger(new_file_logger)
        end

        def swap_in_proxy_logger!
          create_proxy_log_dir!

          proxy_logger = Proxy.new
          # We can use the previous logdev. log_device will continuously call write
          # through the devices until the logdev (@dev) is a File:
          # https://github.com/ruby/ruby/blob/master/lib/logger/log_device.rb#L42
          # Log device holds the configurations around shifting too.
          original_logdevice = log_instance.instance_variable_get("@logdev")
          updated_original_logger = ::Logger.new(original_logdevice)
          updated_original_logger.formatter = log_instance.formatter

          new_file_logger = create_destination_logger

          proxy_logger.add(updated_original_logger)
          proxy_logger.add(new_file_logger)

          if log_instance.class.to_s == Capture::ACTIVESUPPORT_LOGGER
            require 'rails'
            Rails.logger = proxy_logger
          elsif log_instance.class.to_s == Capture::SIDEKIG_LOGGER
            require 'sidekiq'
            Sidekiq.configure_server do |config|
              config.logger = proxy_logger
            end
          elsif log_instance.class.to_s == Capture::TEST_LOGGER
            TestLoggerWrapper.logger = proxy_logger
          end

          path_of_logger(new_file_logger)
        end

        private

        def create_destination_logger
          Destination.new(context, log_instance).create_logger!
        end

        def path_of_logger(logger)
          log_dev = logger.instance_variable_get("@logdev")
          log_dev.filename
        end

        def create_proxy_log_dir!
          Utils.ensure_directory_exists(context.config.value('proxy_log_dir'))
        end
      end
    end
  end
end
