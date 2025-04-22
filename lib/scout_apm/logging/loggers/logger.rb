# frozen_string_literal: true

module ScoutApm
  module Logging
    module Loggers
      # The actual instance of the logger.
      class FileLogger < ::Logger
        include ::ActiveSupport::LoggerSilence if const_defined?('::ActiveSupport::LoggerSilence')

        alias_method :original_warn, :warn
        alias_method :original_info, :info

        # def info(*args)
        #   # Get the caller (this returns the stack trace where the method was called from)
        #   caller_info = caller_locations(1,15)
        #   binding.irb
        #   file = caller_info.path.split("/")[-1]  # Split the string into file and line number
        #   line = caller_info.lineno
    
        #   # Log the message with the file and line number where the log was called
        #   original_warn("(#{file}:#{line}): #{msg}")
        # end

        def warn_first(msg, *args)
            # Get the caller (this returns the stack trace where the method was called from)
            caller_info = caller(1).first  # Get the first entry in the call stack
            file, line = caller_info.split(':')  # Split the string into file and line number

            # Log the message with the file and line number where the log was called
            original_warn("(#{file}:#{line}): #{msg}")
        end

        def warn_two(msg, *args)
          # Get the caller (this returns the stack trace where the method was called from)
          caller_info = caller_locations.lazy.drop(1).first  # Get the first entry in the call stack
          file = caller_info.path.split("/")[-1]  # Split the string into file and line number
          line = caller_info.lineno

          # Log the message with the file and line number where the log was called
          original_warn("(#{file}:#{line}): #{msg}")
        end

      def warn_four(msg, *args)
        # Get the caller (this returns the stack trace where the method was called from)
        caller_info = caller_locations(2,1).first  # Get the first entry in the call stack
        file = caller_info.path.split("/")[-1]  # Split the string into file and line number
        line = caller_info.lineno

        # Log the message with the file and line number where the log was called
        original_warn("(#{file}:#{line}): #{msg}")
    end

    def warn_five(msg, *args)
      # Get the caller (this returns the stack trace where the method was called from)
      caller_info = caller_locations(1,10).find {|loc| loc.path.include?(Rails.root.to_s)}  # Get the first entry in the call stack
      file = caller_info.path.split("/")[-1]  # Split the string into file and line number
      line = caller_info.lineno

      # Log the message with the file and line number where the log was called
      original_warn("(#{file}:#{line}): #{msg}")
    end

    def warn_six(msg, *args)
      # Get the caller (this returns the stack trace where the method was called from)
      caller_info = find_log_location
      
      file = caller_info.path.split("/")[-1]  # Split the string into file and line number
      line = caller_info.lineno

      # Log the message with the file and line number where the log was called
      original_warn("(#{file}:#{line}): #{msg}")
    end

    def warn_seven(msg, *args)
      caller_info = find_log_location_2

      file = caller_info.path.split("/")[-1]  # Split the string into file and line number
      line = caller_info.lineno

      # Log the message with the file and line number where the log was called
      original_warn("(#{file}:#{line}): #{msg}")

      @call_stack = nil
      @find_log_location_2 = nil
    end

    def warn_eight(msg, *args)
      caller_info = find_log_location_2

      file = caller_info.path.split("/")[-1]  # Split the string into file and line number
      line = caller_info.lineno

      # Log the message with the file and line number where the log was called
      original_warn("(#{file}:#{line}): #{msg}")

      get_call_stack_for_attribute
      @call_stack = nil
      @find_log_location_2 = nil
    end

    def warn_nine(msg, *args)
      caller_info = find_log_location_2

      file = caller_info.path.split("/")[-1]  # Split the string into file and line number
      line = caller_info.lineno

      # Log the message with the file and line number where the log was called
      original_warn("(#{file}:#{line}): #{msg}")

      get_call_stack_for_attribute_2
      @call_stack = nil
      @find_log_location_2 = nil
    end

    def warn_ten(msg, *args)
      caller_info = find_log_location_3

      file = caller_info.path.split("/")[-1]  # Split the string into file and line number
      line = caller_info.lineno

      # Log the message with the file and line number where the log was called
      original_warn("(#{file}:#{line}): #{msg}")

      get_call_stack_for_attribute
      @call_stack_2 = nil
      @find_log_location_3 = nil
    end

    def warn_eleven(msg, *args)
      caller_info = find_log_location_2

      file = caller_info.path.split("/")[-1]  # Split the string into file and line number
      line = caller_info.lineno

      # Log the message with the file and line number where the log was called
      original_warn("(#{file}:#{line}): #{msg}")

      Thread.current['scout_log_location'] = get_call_stack_for_attribute
      @call_stack = nil
      @find_log_location_2 = nil
      Thread.current['scout_log_location'] = nil
    end


      def warn_three(msg)
        last_local_location = caller[0..15].find { |path| path.include?(Rails.root.to_s) }
        file = last_local_location.split("/")[-1]  # Split the string into file and line number
        line = last_local_location.split(":")[-1]
        # Log the message with the file and line number where the log was called
        original_warn("(#{file}:#{line}): #{msg}")
      end
      
      # alias_method :warn, :warn_two


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

        def filter_log_location(the_call_stack = caller_locations)
          rails_location = the_call_stack.find { |loc| loc.path.include?(Rails.root.to_s) }
          return rails_location if rails_location

          the_call_stack
            .reject { |loc| loc.path.include?('lib/scout_apm/logging') }
            .reject { |loc| loc.path.include?('broadcast_logger.rb') }
            .first
        end

        def call_stack
          @call_stack ||= caller_locations(4, 15)
        end

        def call_stack_2
          @call_stack_2 ||= caller_locations(4, 20)
        end

        def find_log_location_2
          @find_log_location_2 ||= filter_log_location(call_stack)
        end

        def find_log_location_3
          @find_log_location_3 ||= filter_log_location(call_stack_2)
        end

        def get_call_stack_for_attribute
          call_stack
            .map(&:to_s)
            .reject { |loc| loc.include?('scout_apm/logging') }
            .reject { |loc| loc.include?('broadcast_logger.rb') }
            .join("\n")
        end

        def get_call_stack_for_attribute_2
          call_stack
            .each_with_object([]) do |loc, arr|
              str = loc.to_s
              unless str.include?('scout_apm/logging') || str.include?('broadcast_logger.rb')
                arr << str
              end
            end
            .join("\n")
        end
        

        def find_log_location
          @location ||= begin
            call_stack = caller_locations(1, 15)
            rails_location = call_stack.find { |loc| loc.path.include?(Rails.root.to_s) }
            return rails_location if rails_location
            filtered_locations = call_stack.reject { |loc| loc.path.include?('lib/scout_apm_logging') }
            filtered_locations = call_stack.reject { |loc| loc.path.include?('broadcast_logger.rb') }
            return call_stack.first if filtered_locations.empty?
          end
        end


        def format_message(severity, datetime, progname, msg)
          (@formatter || @default_formatter).call(severity, datetime, progname, msg)
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
