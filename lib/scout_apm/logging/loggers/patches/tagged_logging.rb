# frozen_string_literal: true

require_relative '../logger'
require_relative '../formatter'
require_relative '../proxy'

module ScoutApm
  module Logging
    module Loggers
      module Patches
        module TaggedLogging
          def tagged(*tags)
            if self == Rails.logger
              if self.is_a?(ScoutApm::Logging::Loggers::Proxy)
                if block_given?
                  # TODO: Add suport for block notation
                  self.formatter.tagged(*tags) { yield self }
                else
                  new_loggers = self.instance_variable_get(:@loggers).map do |logger|
                    current_tags = if logger.formatter.respond_to?(:current_tags)
                      logger.formatter.current_tags
                    else
                      []
                    end
      
                    ActiveSupport::TaggedLogging.new(logger).tap do |new_logger|
                      new_logger.formatter.extend ActiveSupport::TaggedLogging::LocalTagStorage if defined?(ActiveSupport::TaggedLogging::LocalTagStorage)
                      new_logger.push_tags(*current_tags, *tags)
                    end
                  end

                  cloned_proxy = self.clone.tap do |cp|
                    cp.instance_variable_set(:@loggers, new_loggers)
                  end
                end
              else
                super(*tags)
              end
            elsif Rails.logger.is_a?(::ActiveSupport::BroadcastLogger) && Rails.logger.broadcasts.include?(self)
              if block_given?
                # TODO: Add suport for block notation
                super(*tags)
              else
                broadcasts = Rails.logger.instance_variable_get(:@broadcasts)

                tagged_loggers = broadcasts.select {|logger| logger.respond_to?(:tagged)}
                current_tags = tagged_loggers.first.formatter.current_tags
    
                updated_tagged_logger = tagged_loggers.map do |logger| 
                  ActiveSupport::TaggedLogging.new(logger).tap do | new_logger|
                    new_logger.formatter.extend ActiveSupport::TaggedLogging::LocalTagStorage if defined?(ActiveSupport::TaggedLogging::LocalTagStorage)
                    new_logger.push_tags(*current_tags, *tags)
                  end
                end

                file_logger = broadcasts.find { |logger| logger.is_a?(Loggers::FileLogger)}
                updated_file_logger = ActiveSupport::TaggedLogging.new(file_logger).tap do |new_logger|
                  new_logger.formatter.extend ActiveSupport::TaggedLogging::LocalTagStorage if defined?(ActiveSupport::TaggedLogging::LocalTagStorage)
                  new_logger.push_tags(*current_tags, *tags)
                end

                loggers = updated_tagged_logger << updated_file_logger

                Proxy.create_with_loggers(*loggers)
              end
            else
              super(*tags)
            end
          end
        end
      end
    end
  end
end
