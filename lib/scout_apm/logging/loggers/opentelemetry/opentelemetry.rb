# frozen_string_literal: true
require 'logger'
require 'opentelemetry'
require 'opentelemetry/sdk'
require 'opentelemetry-logs-sdk'
require 'opentelemetry/exporter/otlp_logs'
require_relative './log_record_patch'

module ScoutApm
  module Logging
    module Loggers
      module OpenTelemetry
        class << self
          def logger_provider=(logger_provider)
            @logger_provider = logger_provider
          end

          def logger_provider
            @logger_provider
          end
        end

        def self.setup(context)
          exporter = ::OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new(endpoint: context.config.value('logs_reporting_endpoint_http'))
          processor = ::OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(exporter)
          OpenTelemetry.logger_provider = ::OpenTelemetry::SDK::Logs::LoggerProvider.new(resource: scout_resource(context))
          OpenTelemetry.logger_provider.add_log_record_processor(processor)
          ::OpenTelemetry.logger = context.logger || ::Logger.new($stdout, level: ENV['OTEL_LOG_LEVEL'] || ::Logger::INFO)
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
