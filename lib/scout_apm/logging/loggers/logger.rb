# frozen_string_literal: true

require 'logger'

module ScoutApm
  module Logging
    module Loggers
      class FileLogger < ::Logger
      end

      # The newly created logger which we can configure, and will log to a filepath.
      class Logger
        attr_reader :context, :log_instance

        # 1 MiB
        LOG_SIZE = 1024 * 1024
        # 1 log file
        LOG_AGE = 1

        def initialize(context, log_instance)
          @context = context
          @log_instance = log_instance
        end

        def create_logger!
          # Defaults are 7 files with 10 MiB.
          # We create the file in order to prevent a creation header log.
          File.new(determine_file_path, 'w+') unless File.exist?(determine_file_path)
          FileLogger.new(determine_file_path, LOG_AGE, LOG_SIZE)
        end

        def determine_file_path # rubocop:disable Metrics/AbcSize
          log_directory = context.config.value('proxy_log_dir')

          original_basename = File.basename(log_destination) if log_destination.is_a?(String)

          file_basename = if original_basename
                            original_basename
                          elsif defined?(::ActiveSupport::Logger) && log_instance.is_a?(::ActiveSupport::Logger)
                            'rails.log'
                          elsif defined?(::ActiveSupport::BroadcastLogger) && log_instance.is_a?(::ActiveSupport::BroadcastLogger)
                            'rails.log'
                          elsif defined?(::Sidekiq::Logger) && log_instance.is_a?(::Sidekiq::Logger)
                            'sidekiq.log'
                          elsif defined?(::ScoutTestLogger) && log_instance.is_a?(::ScoutTestLogger)
                            'test.log'
                          else
                            'mix.log'
                          end

          File.join(log_directory, file_basename)
        end

        private

        def find_log_destination(logdev)
          dev = try(logdev, :filename) || try(logdev, :dev)
          if dev.is_a?(String)
            dev
          elsif dev.respond_to?(:path)
            dev.path
          elsif dev.respond_to?(:filename) || dev.respond_to?(:dev)
            find_log_destination(dev)
          else
            dev
          end
        end

        def log_destination
          @log_destination ||= find_log_destination(log_instance.instance_variable_get(:@logdev))
        end

        def try(obj, method)
          obj.respond_to?(method) ? obj.send(method) : nil
        end
      end
    end
  end
end
