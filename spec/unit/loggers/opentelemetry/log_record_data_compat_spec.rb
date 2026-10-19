require 'spec_helper'

require_relative '../../../../lib/scout_apm/logging/loggers/opentelemetry/opentelemetry'

describe OpenTelemetry::SDK::Logs::LogRecordData do
  let(:exporter) { OpenTelemetry::SDK::Logs::Export::InMemoryLogRecordExporter.new }

  let(:log_record_data) do
    provider = OpenTelemetry::SDK::Logs::LoggerProvider.new
    provider.add_log_record_processor(OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(exporter))

    provider.logger(name: 'scout_apm', version: '0.1.0').on_emit(
      severity_text: 'INFO',
      severity_number: OpenTelemetry::Logs::SeverityNumber::SEVERITY_NUMBER_INFO,
      attributes: { 'controller' => 'UsersController' },
      timestamp: Time.now,
      body: 'Processing by UsersController#index'
    )

    exporter.emitted_log_records.first
  end

  it 'responds to the fields read by every supported exporter version' do
    expect(log_record_data.total_recorded_attributes).to eq(1)
    expect(log_record_data.dropped_attributes_count).to eq(0)
    expect(log_record_data).to respond_to(:event_name)
  end

  it 'exports through the installed OTLP exporter without raising' do
    otlp_exporter = OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new
    # Exporter >= 0.7.0 moved encoding into opentelemetry-exporter-otlp-common.
    encoded = if otlp_exporter.respond_to?(:encode, true)
                otlp_exporter.send(:encode, [log_record_data])
              else
                OpenTelemetry::Exporter::OTLP::Common.as_encoded_elsr([log_record_data])
              end
    request = Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest.decode(encoded)
    record = request.resource_logs.first.scope_logs.first.log_records.first

    expect(record.body.string_value).to eq('Processing by UsersController#index')
    expect(record.severity_number).to eq(:SEVERITY_NUMBER_INFO)
    expect(record.dropped_attributes_count).to eq(0)
  end
end
