# frozen_string_literal: true

require 'logger'

require_relative './opentelemetry/opentelemetry'
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

          OpenTelemetry.setup(context)

          create_proxy_log_dir!

          add_logging_patches!
          capture_and_swap_log_locations!
        end

        private

        def create_proxy_log_dir!
          Utils.ensure_directory_exists(context.config.value('logs_proxy_log_dir'))
        end

        def add_logging_patches! # rubocop:disable Metrics/AbcSize
          require_relative './patches/rails_logger' unless ::Rails.logger.respond_to?(:broadcasts)
          # We can't swap out the logger similar to that of Rails and Sidekiq, as
          # the TaggedLogging logger is dynamically generated.
          return unless ::Rails.logger.respond_to?(:tagged)

          ::ActiveSupport::TaggedLogging.prepend(Patches::TaggedLogging)

          # Re-extend TaggedLogging to verify the patch is be applied.
          # This appears to be an issue in Ruby 2.7 with the broadcast logger.
          ruby_version = Gem::Version.new(RUBY_VERSION)
          isruby27 = ruby_version >= Gem::Version.new('2.7') && ruby_version < Gem::Version.new('3.0')
          return unless isruby27 && ::Rails.logger.respond_to?(:broadcasts)

          ::Rails.logger.broadcasts.each do |logger|
            logger.extend ::ActiveSupport::TaggedLogging
          end
        end

        def capture_and_swap_log_locations!
          # We can move this to filter_map when our lagging version is Ruby 2.7
          updated_log_locations = KNOWN_LOGGERS.map do |logger|
            logger.new(context).update_logger! if logger.present?
          end
          updated_log_locations.compact!
        end
      end
    end
  end
end
