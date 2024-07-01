require 'logger'

module ScoutApm
  module Logging
    module Loggers
      class FileLogger < ::Logger
      end

      class Destination
        attr_reader :context
        attr_reader :log_instance

        # 1 MiB
        LOG_SIZE = 1024*1024
        # 1 log file
        LOG_AGE = 1

        def initialize(context, log_instance)
          @context = context
          @log_instance = log_instance
        end

        def create_logger!
          # Defaults are 7 files with 10 MiB.
          FileLogger.new(determine_file_path, LOG_AGE, LOG_SIZE)
        end

        def determine_file_path
          log_directory =  context.config.value('proxy_log_dir')
          file_path = case log_instance.class.to_s
          when Capture::ACTIVESUPPORT_LOGGER
            File.join(log_directory, 'rails.log')
          when Capture::SIDEKIG_LOGGER
            File.join(log_directory, 'sidekiq.log')
          when Capture::TEST_LOGGER
            File.join(log_directory, 'test.log')
          else
            # Shouldn't be possible.
            File.join(log_directory, 'mix.log')
          end   
        end
      end
    end
  end
end
