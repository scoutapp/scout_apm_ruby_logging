# frozen_string_literal: true

module ScoutApm
  module Logging
    module Loggers
      # The actual instance of the logger.
      class FileLogger < ::Logger
        include ::ActiveSupport::LoggerSilence if const_defined?('::ActiveSupport::LoggerSilence')

        # Taken from ::Logger. Progname becomes message if no block is given.
        def debug(progname = nil, &block)
          return true if level > DEBUG

          # short circuit the block to update the message. #add would eventually call it.
          # https://github.com/ruby/logger/blob/v1.7.0/lib/logger.rb#L675
          progname = yield if block_given?
          message = add_log_file_and_line_to_message(progname) if progname
          add(DEBUG, message, nil, &block)
        end

        def info(progname = nil, &block)
          return true if level > INFO

          progname = yield if block_given?
          message = add_log_file_and_line_to_message(progname) if progname
          add(INFO, message, nil, &block)
        end

        def warn(progname = nil, &block)
          return true if level > WARN

          progname = yield if block_given?
          message = add_log_file_and_line_to_message(progname) if progname
          add(WARN, message, nil, &block)
        end

        def error(progname = nil, &block)
          return true if level > ERROR

          progname = yield if block_given?
          message = add_log_file_and_line_to_message(progname) if progname
          add(ERROR, message, nil, &block)
        end

        def fatal(progname = nil, &block)
          return true if level > FATAL

          progname = yield if block_given?
          message = add_log_file_and_line_to_message(progname) if progname
          add(FATAL, message, nil, &block)
        end

        def unknown(progname = nil, &block)
          return true if level > UNKNOWN

          progname = yield if block_given?
          message = add_log_file_and_line_to_message(progname) if progname
          add(UNKNOWN, message, nil, &block)
        end

        # Other loggers may be extended with additional methods that have not been applied to this file logger.
        # Most likely, these methods will still utilize the exiting logging methods to write to the IO device,
        # however, if this is not the case we may miss logs. With that being said, we shouldn't impact the original
        # applications intended behavior and let the user know we don't support it and no-op.
        def method_missing(name, *_args)
          return unless defined?(::Rails)

          ::Rails.logger.warn("Method #{name} called on ScoutApm::Logging::Loggers::FileLogger, but it is not defined.")
        end

        # More impactful for the broadcast logger.
        def respond_to_missing?(name, *_args)
          super
        end

        private

        def first_app_location(locations = caller_locations)
          locations.find { |loc| loc.path.include?(Rails.root.to_s) }
        end

        def add_log_file_and_line_to_message(message)
          return message unless message.is_a?(String)

          file = first_app_location(caller_locations(1, 10))
          return message unless file

          file_path = file.path.split('/').last
          line_number = file.lineno

          "[#{file_path}:#{line_number}] #{message}"
        end
      end

      # The newly created logger which we can configure, and will log to a filepath.
      class Logger
        attr_reader :context, :log_instance

        # 1 log file
        LOG_AGE = 1

        def initialize(context, log_instance)
          @context = context
          @log_instance = log_instance
        end

        def create_logger!
          # We create the file in order to prevent a creation header log.
          File.new(determine_file_path, 'w+') unless File.exist?(determine_file_path)
          log_size = context.config.value('logs_log_file_size')

          FileLogger.new(determine_file_path, LOG_AGE, log_size).tap do |logger|
            # Ruby's Logger handles a lot of the coercion itself.
            logger.level = determined_log_level
            # Add our custom formatter to the logger.
            logger.formatter = Formatter.new
          end
        end

        def determine_file_path # rubocop:disable Metrics/AbcSize
          log_directory = context.config.value('logs_proxy_log_dir')

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

        # This makes the assumption that the logs we capture should be
        # at least that of the original logger level, and not lower, but can be
        # configured to be a higher cutoff.
        def determined_log_level
          capture_level = context.config.value('logs_capture_level')
          capture_value = ::Logger::Severity.const_get(capture_level.upcase)

          log_instance_value = if log_instance.level.is_a?(Integer)
                                 log_instance.level
                               else
                                 ::Logger::Severity.const_get(log_instance.level.to_s.upcase)
                               end

          [capture_value, log_instance_value].max
        end

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
