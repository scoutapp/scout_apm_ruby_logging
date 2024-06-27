require 'logger'

module ScoutApm
  module Logging
    module Loggers
      class Capture
        attr_reader :context

        # TODO: Add more supported / known loggers.
        KNOWN_LOGGERS = [
          BROADCAST_LOGGER = 'ActiveSupport::BroadcastLogger',
          ACTIVESUPPORT_LOGGER = 'ActiveSupport::Logger',
          SIDEKIG_LOGGER = 'Sidekiq::Logger',
          # Internal logger for testing.
          TEST_LOGGER = 'ScoutTestLogger'
        ]

        def initialize(context)
          @context = context

          @new_log_locations = []
        end

        def capture_log_locations!
          logger_instances = ObjectSpace.each_object(::Logger)
            .select { |logger| KNOWN_LOGGERS.include? logger.class.to_s }

          new_log_locations = []
          logger_instances.each do |log_instance|
            log_devices = get_log_devices(log_instance)
            log_locations = get_log_location(log_devices)

            log_locations.each do |location|
              # TODO: Add a proxy logger if we are logging to STDOUT
              next if location == STDOUT

              new_log_locations << location
            end
          end
          
          context.config.state.add_log_locations!(new_log_locations)
        end

        private

        # In Rails 7.1, broadcast logger was added which allows sinking to multiple IO devices.
        def get_log_devices(log_instance)
          # https://github.com/rails/rails/blob/main/activesupport/lib/active_support/logger.rb#L20
          loggers = 
            if log_instance.class.to_s == BROADCAST_LOGGER
              log_instance.broadcasts
            else
              [log_instance]
            end
      
          loggers.map { |logger| logger.instance_variable_get(:@logdev) }
        end

        def get_log_location(log_devices)
          log_devices.map {|logdev| try(logdev, 'filename') || try(logdev, 'dev')}.compact
        end

        # A minimal recreation of Rails 'try'.
        def try(obj, method)
          obj.public_send(method) if obj.respond_to? method
        end
      end
    end
  end
end
