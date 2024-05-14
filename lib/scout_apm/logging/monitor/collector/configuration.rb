# frozen_string_literal: true

module ScoutApm
  module Logging
    module Collector
      # Creates the configuration to be used when launching the collector.
      class Configuration
        attr_reader :context

        def initialize(context)
          @context = context
        end

        def setup!
          create_config_file
        end

        def create_config_file
          File.write(config_file, config_contents)
        end

        private

        def config_file
          context.config.value('collector_config_file')
        end

        def config_contents
          <<~CONFIG
            receivers:
              filelog:
                include: [#{context.config.value('monitored_logs').join(',')}]
            processors:
              batch:
            exporters:
              otlp:
                endpoint: #{context.config.value('logs_reporting_endpoint')}
                headers:
                  x-telemetryhub-key: #{context.config.value('logging_ingest_key')}
            extensions:
              health_check:
                endpoint: #{health_check_endpoint}
            service:
              extensions:
                - health_check
              pipelines:
                logs:
                  receivers:
                    - filelog
                  processors:
                    - batch
                  exporters:
                    - otlp
          CONFIG
        end

        def health_check_endpoint
          "localhost:#{context.health_check_port}"
        end
      end
    end
  end
end
