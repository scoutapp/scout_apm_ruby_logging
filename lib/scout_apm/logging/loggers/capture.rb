# frozen_string_literal: true

require 'logger'

require_relative './formatter'
require_relative './logger'
require_relative './proxy'
require_relative './swaps/rails'
require_relative './swaps/sidekiq'
require_relative './swaps/scout'
require_relative './patches/tagged_logging'

module ScoutApm
  module Logging
    module Loggers
      # Will capture the log destinations from the application's loggers.
      class Capture
        attr_reader :context

        KNOWN_LOGGERS = [
          Swaps::Rails,
          Swaps::Sidekiq,
          Swaps::Scout
        ].freeze

        def initialize(context)
          @context = context
        end

        def setup!
          return unless context.config.value('logs_monitor')

          create_proxy_log_dir!

          add_logging_patches!
          capture_and_swap_log_locations!
        end

        private

        def create_proxy_log_dir!
          Utils.ensure_directory_exists(context.config.value('logs_proxy_log_dir'))
        end

        def add_logging_patches!
          # We can't swap out the logger similar to that of Rails and Sidekiq, as
          # the TaggedLogging logger is dynamically generated.
          return unless defined?(::ActiveSupport::TaggedLogging)

          require_relative './patches/rack_logger'

          ::ActiveSupport::TaggedLogging.prepend(Patches::TaggedLogging)
        end

        def capture_and_swap_log_locations!
          # We can move this to filter_map when our lagging version is Ruby 2.7
          updated_log_locations = KNOWN_LOGGERS.map do |logger|
            logger.new(context).update_logger! if logger.present?
          end
          updated_log_locations.compact!

          context.config.state.add_log_locations!(updated_log_locations)
        end
      end
    end
  end
end
