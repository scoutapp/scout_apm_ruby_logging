require 'logger'

require 'spec_helper'

require_relative '../../../../lib/scout_apm/logging/loggers/opentelemetry/opentelemetry'

describe OpenTelemetry::Exporter::OTLP::Logs::LogsExporter do
  let(:log_record_data) do
    exporter = OpenTelemetry::SDK::Logs::Export::InMemoryLogRecordExporter.new
    provider = OpenTelemetry::SDK::Logs::LoggerProvider.new
    provider.add_log_record_processor(OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(exporter))

    provider.logger(name: 'scout_apm', version: '0.1.0').on_emit(
      severity_text: 'INFO',
      severity_number: ::Logger::Severity::INFO,
      attributes: { 'controller' => 'UsersController' },
      timestamp: Time.now,
      body: 'Processing by UsersController#index'
    )

    exporter.emitted_log_records.first
  end

  describe '#as_otlp_log_record' do
    subject(:otlp_log_record) { described_class.new.as_otlp_log_record(log_record_data) }

    it 'encodes the body, severity and attributes' do
      expect(otlp_log_record.body.string_value).to eq('Processing by UsersController#index')
      expect(otlp_log_record.severity_text).to eq('INFO')
      expect(otlp_log_record.severity_number).to eq(:SEVERITY_NUMBER_INFO)
      expect(otlp_log_record.attributes.map(&:key)).to eq(['controller'])
    end

    it 'reports no dropped attributes when none were dropped' do
      expect(otlp_log_record.dropped_attributes_count).to eq(0)
    end
  end
end
