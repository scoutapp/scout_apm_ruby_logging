module OpenTelemetry
  module Exporter
    module OTLP
      module Logs
        # Patch the log record creation to add back severity number.
        class LogsExporter
          def as_otlp_log_record(log_record_data)
            Opentelemetry::Proto::Logs::V1::LogRecord.new(
              time_unix_nano: log_record_data.timestamp,
              observed_time_unix_nano: log_record_data.observed_timestamp,
              severity_number: as_otlp_severity_number(log_record_data.severity_number),
              severity_text: log_record_data.severity_text,
              body: as_otlp_any_value(log_record_data.body),
              attributes: log_record_data.attributes&.map { |k, v| as_otlp_key_value(k, v) },
              dropped_attributes_count: log_record_data.total_recorded_attributes - log_record_data.attributes&.size.to_i,
              flags: log_record_data.trace_flags.instance_variable_get(:@flags),
              trace_id: log_record_data.trace_id,
              span_id: log_record_data.span_id
            )
          end

          # TODO: This has been removed in newer versions of the OpenTelemetry Ruby Logs SDK, however
          # it appears that we are missing the severity number. Investigate this.
          def as_otlp_severity_number(severity_number)
            case severity_number
            when 0 then Opentelemetry::Proto::Logs::V1::SeverityNumber::SEVERITY_NUMBER_DEBUG
            when 1 then Opentelemetry::Proto::Logs::V1::SeverityNumber::SEVERITY_NUMBER_INFO
            when 2 then Opentelemetry::Proto::Logs::V1::SeverityNumber::SEVERITY_NUMBER_WARN
            when 3 then Opentelemetry::Proto::Logs::V1::SeverityNumber::SEVERITY_NUMBER_ERROR
            when 4 then Opentelemetry::Proto::Logs::V1::SeverityNumber::SEVERITY_NUMBER_FATAL
            when 5 then Opentelemetry::Proto::Logs::V1::SeverityNumber::SEVERITY_NUMBER_UNSPECIFIED
            end
          end
        end
      end
    end
  end
end
