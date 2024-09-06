# frozen_string_literal: true

module ScoutApm
  module Logging
    module Loggers
      # Holds both the original application logger and the new one. Relays commands to both.
      class Proxy
        def self.create_with_loggers(*loggers)
          new.tap do |proxy_logger|
            loggers.each { |logger| proxy_logger.add_scout_loggers(logger) }
          end
        end

        def initialize
          @loggers = []
        end

        def add_scout_loggers(logger)
          @loggers << logger
        end

        def remove_scout_loggers!(logger)
          @loggers.reject! { |inst_log| inst_log == logger }

          @loggers
        end

        def swap_scout_loggers!(old_logger, new_logger)
          logger_index = @loggers.index(old_logger)
          return unless logger_index

          @loggers[logger_index] = new_logger
        end

        # We don't want other libraries to change the formatter of the logger we create.
        def formatter=(formatter)
          @loggers.first.formatter = formatter
        end

        # We don't want other libraries to change the level of the logger we create, as this
        # is dictated by the logs_capture_level configuration.
        def level=(level)
          @loggers.first.level = level
        end

        def is_a?(klass)
          @loggers.first.is_a?(klass)
        end

        def kind_of?(klass)
          @loggers.first.is_a?(klass)
        end

        def instance_of?(klass)
          @loggers.first.instance_of?(klass)
        end

        def class
          @loggers.first.class
        end

        def is_scout_proxy_logger?
          true
        end

        def method_missing(name, *args, &block)
          # Some libraries will do stuff like Library.logger.formatter = Rails.logger.formatter
          # As such, we should return the first logger's (the original logger) return value.
          return_value = @loggers.first.send(name, *args, &block)
          @loggers[1..].each { |logger| logger.send(name, *args, &block) }

          return_value
        end

        def respond_to_missing?(name, *args)
          @loggers.first.respond_to?(name, *args) || super
        end
      end
    end
  end
end
