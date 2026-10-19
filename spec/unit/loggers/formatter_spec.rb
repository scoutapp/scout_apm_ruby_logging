require 'json'
require 'logger'
require 'stringio'

require 'spec_helper'

require 'scout_apm_logging'

describe ScoutApm::Logging::Loggers::Formatter do
  context 'severity' do
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

  context 'encoding' do
    let(:formatter) { ScoutApm::Logging::Loggers::Formatter.new }
    let(:otel_logger) { double(on_emit: nil) }

    before do
      allow(ScoutApm::Logging::Loggers::OpenTelemetry).to receive(:logger_provider).and_return(double(logger: otel_logger))
    end

    it 'should replace bytes that are not valid UTF-8' do
      line = formatter.call('INFO', Time.now, nil, "bad \xFF byte")

      expect(JSON.parse(line)['msg']).to eq("bad \u{FFFD} byte")
    end

    it 'should read binary text, as a request path is logged, as UTF-8' do
      line = formatter.call('INFO', Time.now, nil, 'café /x?%FF'.b + "\xFF".b)

      expect(JSON.parse(line)['msg']).to eq("café /x?%FF\u{FFFD}")
    end

    it 'should keep valid text in another encoding' do
      line = formatter.call('INFO', Time.now, nil, 'café'.encode('UTF-16LE'))

      expect(JSON.parse(line)['msg']).to eq('café')
    end

    it 'should replace bad bytes in an exception message' do
      line = formatter.call('ERROR', Time.now, nil, RuntimeError.new("bad \xFF byte".b))

      expect(JSON.parse(line)['msg']).to eq("bad \u{FFFD} byte (RuntimeError)\n")
    end

    it 'should emit the replaced text as the OpenTelemetry body' do
      formatter.call('INFO', Time.now, nil, "bad \xFF byte".b)

      expect(otel_logger).to have_received(:on_emit).with(hash_including(body: "bad \u{FFFD} byte"))
    end
  end
end
