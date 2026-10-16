# frozen_string_literal: true

module OpenTelemetry
  module SDK
    module Logs
      # The OTLP logs exporter and the logs SDK are versioned independently, and every exporter
      # release only requires `opentelemetry-logs-sdk ~> 0.1`, so Bundler can resolve pairs that
      # disagree on LogRecordData's fields:
      #   * exporter <= 0.5.1 reads `total_recorded_attributes`, which logs-sdk >= 0.7.0 replaced
      #     with `dropped_attributes_count` (read by exporter >= 0.6.0). See #114.
      #   * exporter >= 0.5.0 reads `event_name`, which logs-sdk < 0.6.0 does not have.
      # Define whichever of these is missing so any resolved pair can export.
      class LogRecordData
        unless method_defined?(:total_recorded_attributes)
          def total_recorded_attributes
            attributes&.size.to_i + dropped_attributes_count.to_i
          end
        end

        unless method_defined?(:dropped_attributes_count)
          def dropped_attributes_count
            [total_recorded_attributes.to_i - attributes&.size.to_i, 0].max
          end
        end

        unless method_defined?(:event_name)
          def event_name
            nil
          end
        end
      end
    end
  end
end
