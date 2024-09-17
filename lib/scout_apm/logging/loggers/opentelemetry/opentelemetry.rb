# frozen_string_literal: true
require 'logger'
require 'opentelemetry'
require 'opentelemetry/sdk'

require_relative 'api/logs'
require_relative 'sdk/logs'
require_relative 'exporter/exporter/otlp/version'
require_relative 'exporter/exporter/otlp/logs_exporter'

module ScoutApm
  module Logging
    module Loggers
      module OpenTelemetry
        class << self
          # Overwritten on setup to be the internal logger.
          # @return [Object, Logger] configured Logger or a default STDOUT Logger.
          def logger
            @logger ||= ::Logger.new($stdout, level: ENV['OTEL_LOG_LEVEL'] || ::Logger::INFO)
          end

          # @return [Callable] configured error handler or a default that logs the
          #   exception and message at ERROR level.
          def error_handler
            @error_handler ||= ->(exception: nil, message: nil) { logger.error("OpenTelemetry error: #{[message, exception&.message, exception&.backtrace&.first].compact.join(' - ')}") }
          end

          # Handles an error by calling the configured error_handler.
          #
          # @param [optional Exception] exception The exception to be handled
          # @param [optional String] message An error message.
          def handle_error(exception: nil, message: nil)
            error_handler.call(exception: exception, message: message)
          end

          def logger_provider=(logger_provider)
            @logger_provider = logger_provider
          end

          def logger_provider
            @logger_provider
          end
        end

        def self.setup(context)
          @logger = context.logger

          exporter = OpenTelemetry::Exporter::OTLP::LogsExporter.new(endpoint: context.config.value('logs_reporting_endpoint_http'))
          processor = OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(exporter)
          ScoutApm::Logging::Loggers::OpenTelemetry.logger_provider = OpenTelemetry::SDK::Logs::LoggerProvider.new(resource: scout_resource(context))
          ScoutApm::Logging::Loggers::OpenTelemetry.logger_provider.add_log_record_processor(processor)
        end

        def self.scout_resource(context)
          our_resources = ::OpenTelemetry::SDK::Resources::Resource.create({'telemetryhub.key' => context.config.value('logs_ingest_key')})
          default_resources = ::OpenTelemetry::SDK::Resources::Resource.default
          default_resources.merge(our_resources)
        end
      end
    end
  end
end
