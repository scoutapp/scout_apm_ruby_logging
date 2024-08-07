# frozen_string_literal: true

module ScoutApm
  module Logging
    module Loggers
      # Holds both the original application logger and the new one. Relays commands to both.
      class Proxy
        def self.create_with_loggers(*loggers)
          new.tap do |proxy_logger|
            loggers.each { |logger| proxy_logger.add(logger) }
          end
        end

        def initialize
          @loggers = []
        end

        def add(logger)
          @loggers << logger
        end

        def remove(logger)
          @loggers.reject! { |inst_log| inst_log == logger }

          @loggers
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
