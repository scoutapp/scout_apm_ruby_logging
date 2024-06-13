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
          create_storage_directories

          create_config_file
        end

        def create_config_file
          File.write(config_file, config_contents)
        end

        private

        def create_storage_directories
          # Sending queue storage directory
          Utils.ensure_directory_exists(context.config.value('collector_sending_queue_storage_dir'))
          # Offset storage directory
          Utils.ensure_directory_exists(context.config.value('collector_offset_storage_dir'))
        end

        def config_file
          context.config.value('collector_config_file')
        end

        def config_contents
          <<~CONFIG
            receivers:
              filelog:
                include: [#{context.config.value('monitored_logs').join(',')}]
                storage: file_storage/filelogreceiver
            processors:
              batch:
            exporters:
              otlp:
                endpoint: #{context.config.value('logs_reporting_endpoint')}
                headers:
                  x-telemetryhub-key: #{context.config.value('logging_ingest_key')}
                sending_queue:
                  storage: file_storage/otc
            extensions:
              health_check:
                endpoint: #{health_check_endpoint}
              file_storage/filelogreceiver:
                directory: #{context.config.value('collector_offset_storage_dir')}
              file_storage/otc:
                directory: #{context.config.value('collector_sending_queue_storage_dir')}
                timeout: 10s
            service:
              extensions:
                - health_check
                - file_storage/filelogreceiver
                - file_storage/otc
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
