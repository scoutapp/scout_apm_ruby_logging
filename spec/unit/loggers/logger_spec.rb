require 'logger'
require 'stringio'

require 'spec_helper'

require 'scout_apm_logging'

ScoutApm::Logging::Loggers::Formatter.class_exec do
  define_method(:emit_log) do |msg, severity, time, attributes_to_log|
  end
end

def capture_stdout
  old_stdout = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = old_stdout
end

describe ScoutApm::Logging::Loggers::Logger do
  it 'should not capture call stack or log line' do
    ScoutApm::Logging::Context.instance

    output_from_log = capture_stdout do
      logger = ScoutApm::Logging::Loggers::FileLogger.new($stdout).tap do |instance|
        instance.level = 0
        instance.formatter = ScoutApm::Logging::Loggers::Formatter.new
      end

      logger.info('Hi')
    end

    expect(output_from_log).not_to include('"log_location":"')
    expect(output_from_log).not_to include('"msg":"[logger_spec.rb')
  end

  it 'should capture call stack' do
    ENV['SCOUT_LOGS_CAPTURE_CALL_STACK'] = 'true'
    ScoutApm::Logging::Context.instance

    output_from_log = capture_stdout do
      logger = ScoutApm::Logging::Loggers::FileLogger.new($stdout).tap do |instance|
        instance.level = 0
        instance.formatter = ScoutApm::Logging::Loggers::Formatter.new
      end

      logger.info('Hi')
    end

    expect(output_from_log).to include('"log_location":"')
    expect(output_from_log).not_to include('"msg":"[logger_spec.rb')
    ENV['SCOUT_LOGS_CAPTURE_LOG_LINE'] = 'false' # set back to default
  end

  it 'should capture log line and call stack' do
    ENV['SCOUT_LOGS_CAPTURE_CALL_STACK'] = 'true'
    ENV['SCOUT_LOGS_CAPTURE_LOG_LINE'] = 'true'

    ScoutApm::Logging::Context.instance

    output_from_log = capture_stdout do
      logger = ScoutApm::Logging::Loggers::FileLogger.new($stdout).tap do |instance|
        instance.level = 0
        instance.formatter = ScoutApm::Logging::Loggers::Formatter.new
      end

      logger.info('Hi')
    end

    expect(output_from_log).to include('"msg":"[logger_spec.rb')
    expect(output_from_log).to include('"log_location":"')
    ENV['SCOUT_LOGS_CAPTURE_CALL_STACK'] = 'false' # set back to default
    ENV['SCOUT_LOGS_CAPTURE_LOG_LINE'] = 'false' # set back to default
  end

  it 'should capture log line' do
    ENV['SCOUT_LOGS_CAPTURE_LOG_LINE'] = 'true'
    ScoutApm::Logging::Context.instance

    output_from_log = capture_stdout do
      logger = ScoutApm::Logging::Loggers::FileLogger.new($stdout).tap do |instance|
        instance.level = 0
        instance.formatter = ScoutApm::Logging::Loggers::Formatter.new
      end

      logger.info('Hi')
    end

    expect(output_from_log).not_to include('"log_location":"')
    expect(output_from_log).to include('"msg":"[logger_spec.rb')
    ENV['SCOUT_LOGS_CAPTURE_LOG_LINE'] = 'false' # set back to default
  end
end
