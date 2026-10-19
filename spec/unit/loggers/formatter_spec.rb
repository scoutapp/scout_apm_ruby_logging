require 'logger'
require 'stringio'

require 'spec_helper'

require 'scout_apm_logging'

describe ScoutApm::Logging::Loggers::Formatter do
  let(:exporter) { OpenTelemetry::SDK::Logs::Export::InMemoryLogRecordExporter.new }

  before do
    ScoutApm::Logging::Context.instance

    provider = OpenTelemetry::SDK::Logs::LoggerProvider.new
    provider.add_log_record_processor(OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(exporter))
    ScoutApm::Logging::Loggers::OpenTelemetry.logger_provider = provider
  end

  {
    'DEBUG' => :SEVERITY_NUMBER_DEBUG,
    'INFO' => :SEVERITY_NUMBER_INFO,
    'WARN' => :SEVERITY_NUMBER_WARN,
    'ERROR' => :SEVERITY_NUMBER_ERROR,
    'FATAL' => :SEVERITY_NUMBER_FATAL,
    'ANY' => :SEVERITY_NUMBER_FATAL,
    'SOMETHING_ELSE' => :SEVERITY_NUMBER_UNSPECIFIED
  }.each do |label, expected|
    it "emits #{expected} for #{label}" do
      described_class.new.call(label, Time.now, nil, 'msg')

      record = exporter.emitted_log_records.last
      expect(record.severity_text).to eq(label)
      expect(record.severity_number).to eq(OpenTelemetry::Logs::SeverityNumber.const_get(expected))
    end
  end

  it 'maps Logger#unknown to FATAL' do
    logger = ::Logger.new(StringIO.new)
    logger.formatter = described_class.new
    logger.unknown('gone')

    expect(exporter.emitted_log_records.last.severity_number).to eq(OpenTelemetry::Logs::SeverityNumber::SEVERITY_NUMBER_FATAL)
  end
end
