# frozen_string_literal: true

module ScoutApm
  module Logging
    module Loggers
      module Patches
        # Set severity to default, as we don't really have a severity for a puts log.
        class PutsFormatter < ScoutApm::Logging::Loggers::Formatter
          private

          def determine_severity(_)
            'default'
          end
        end

        # Patches puts to work with our loggers.
        module Puts
          def scout_logger
            @scout_logger ||= create_scout_logger
          end

          def puts(*args)
            args.each do |arg|
              scout_logger.info(arg)
            end

            super
          end

          def create_scout_logger
            context = ScoutApm::Logging::MonitorManager.instance.context
            log_directory = context.config.value('logs_proxy_log_dir')
            log_path = File.join(log_directory, 'puts.log')

            log_age = ScoutApm::Logging::Loggers::Logger::LOG_AGE

            log_size = context.config.value('logs_log_file_size')

            # We create the file in order to prevent a creation header log.
            File.new(log_path, 'w+') unless File.exist?(log_path)

            ScoutApm::Logging::Loggers::FileLogger.new(log_path, log_age, log_size).tap do |logger|
              logger.formatter = PutsFormatter.new
            end
          end
        end
      end
    end
  end
end
