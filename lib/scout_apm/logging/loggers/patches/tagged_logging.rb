# frozen_string_literal: true

require_relative '../logger'
require_relative '../formatter'
require_relative '../proxy'

module ScoutApm
  module Logging
    module Loggers
      module Patches
        # Patches TaggedLogging to work with our loggers.
        module TaggedLogging
          def tagged(*tags) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
            return super(*tags) unless (self == ::Rails.logger && respond_to?(:is_scout_proxy_logger?)) ||
                                       (::Rails.logger.respond_to?(:broadcasts) && ::Rails.logger.broadcasts.include?(self))

            if respond_to?(:is_scout_proxy_logger?)
              if block_given?
                # We skip the first logger to prevent double tagging when calling formatter.tagged
                loggers = @loggers[1..]
                pushed_counts = extend_and_push_tags(loggers, *tags)

                begin
                  formatter.tagged(*tags) { yield self }.tap do
                    logger_pop_tags(loggers, pushed_counts)
                  end
                rescue StandardError => e
                  logger_pop_tags(loggers, pushed_counts)
                  raise e
                end
              else
                loggers = instance_variable_get(:@loggers)

                new_loggers = create_cloned_extended_loggers(loggers, nil, *tags)

                self.clone.tap do |cp| # rubocop:disable Style/RedundantSelf
                  cp.instance_variable_set(:@loggers, new_loggers)
                end
              end
            elsif block_given?
              # We skip the first logger to prevent double tagging when calling formatter.tagged
              loggers = ::Rails.logger.broadcasts[1..]
              pushed_counts = extend_and_push_tags(loggers, *tags)
              begin
                formatter.tagged(*tags) { yield self }.tap do
                  logger_pop_tags(loggers, pushed_counts)
                end
              rescue StandardError => e
                logger_pop_tags(loggers, pushed_counts)
                raise e
              end
            else
              broadcasts = ::Rails.logger.broadcasts

              tagged_loggers = broadcasts.select { |logger| logger.respond_to?(:tagged) }
              file_logger = broadcasts.find { |logger| logger.is_a?(Loggers::FileLogger) }
              loggers = tagged_loggers << file_logger

              current_tags = tagged_loggers.first.formatter.current_tags

              new_loggers = create_cloned_extended_loggers(loggers, current_tags, *tags)
              Proxy.create_with_loggers(*new_loggers)
            end
          end

          def create_cloned_extended_loggers(loggers, current_tags = nil, *tags)
            loggers.map do |logger|
              logger_current_tags = if current_tags
                                      current_tags
                                    elsif logger.formatter.respond_to?(:current_tags)
                                      logger.formatter.current_tags
                                    else
                                      []
                                    end

              ::ActiveSupport::TaggedLogging.new(logger).tap do |new_logger|
                if defined?(::ActiveSupport::TaggedLogging::LocalTagStorage)
                  new_logger.formatter.extend ::ActiveSupport::TaggedLogging::LocalTagStorage
                end
                new_logger.push_tags(*logger_current_tags, *tags)
              end
            end
          end

          def extend_and_push_tags(loggers, *tags)
            loggers.map do |logger|
              logger.formatter.extend ::ActiveSupport::TaggedLogging::Formatter unless logger.formatter.respond_to?(:tagged)

              logger.formatter.push_tags(tags).size
            end
          end

          def logger_pop_tags(loggers, pushed_counts)
            loggers.map.with_index do |logger, index|
              logger.formatter.pop_tags(pushed_counts[index])
            end
          end
        end
      end
    end
  end
end
