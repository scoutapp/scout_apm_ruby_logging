# frozen_string_literal: true

module ScoutApm
  module Logging
    module Collector
      # Adds a method to Hash similar to that of the Rails deep_merge.
      module HashDeepMerge
        refine Hash do
          def deep_merge(second)
            merger = proc { |_, v1, v2|
              if v1.is_a?(Hash) && v2.is_a?(Hash)
                v1.merge(v2, &merger)
              elsif v1.is_a?(Array) && v2.is_a?(Array)
                v1 | v2
              else
                [:undefined, nil, :nil].include?(v2) ? v1 : v2
              end
            }
            merge(second.to_h, &merger)
          end
        end
      end

      # Creates the configuration to be used when launching the collector.
      class Configuration
        using HashDeepMerge

        attr_reader :context

        def initialize(context)
          @context = context
        end

        def setup!
          create_storage_directories

          create_config_file
        end

        def create_config_file
          contents = YAML.dump(combined_contents)
          File.write(config_file, contents)
        end

        private

        def create_storage_directories
          # Sending queue storage directory
          Utils.ensure_directory_exists(context.config.value('collector_sending_queue_storage_dir'))
          # Offset storage directory
          Utils.ensure_directory_exists(context.config.value('collector_offset_storage_dir'))
        end

        def combined_contents
          default_contents = YAML.safe_load(config_contents)

          default_contents.deep_merge(loaded_config_contents)
        end

        def loaded_config_contents
          config_path = context.config.value('logs_config')

          if config_path && File.exist?(config_path)
            YAML.load_file(config_path) || {}
          elsif File.exist?(assumed_config_file_path)
            YAML.load_file(assumed_config_file_path) || {}
          else
            {}
          end
        end

        def config_file
          context.config.value('collector_config_file')
        end

        def config_contents
          <<~CONFIG
            receivers:
              filelog:
                include: [#{context.config.value('logs_monitored').join(',')}]
                storage: file_storage/filelogreceiver
                operators:
                  - type: json_parser
                    severity:
                      parse_from: attributes.severity
                    timestamp:
                      parse_from: attributes.time
                      layout: "%Y-%m-%dT%H:%M:%S.%LZ"
            processors:
              transform:
                log_statements:
                  - context: log
                    statements:
                    # Copy original body to raw_bytes attribute.
                    - 'set(attributes["raw_bytes"], body)'
                    # Replace the body with the log message.
                    - 'set(body, attributes["msg"])'
                    # Move service.name attribute to resource attribute.
                    - 'set(resource.attributes["service.name"], attributes["service.name"])'
              batch:
            exporters:
              otlp:
                endpoint: #{context.config.value('logs_reporting_endpoint')}
                headers:
                  x-telemetryhub-key: #{context.config.value('logs_ingest_key')}
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
                    - transform
                    - batch
                  exporters:
                    - otlp
              telemetry:
                metrics:
                  level: none
          CONFIG
        end

        def health_check_endpoint
          "localhost:#{context.config.value('health_check_port')}"
        end

        def assumed_config_file_path
          "#{context.application_root}/config/scout_logs_config.yml"
        end
      end
    end
  end
end
