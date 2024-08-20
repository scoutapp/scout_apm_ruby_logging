require 'logger'
require 'stringio'

require 'spec_helper'

require_relative '../../../lib/scout_apm/logging/loggers/capture'

def capture_stdout
  old_stdout = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = old_stdout
end

describe ScoutApm::Logging::Loggers::Capture do
  it 'should swap the STDOUT logger and create a proxy logger' do
    ENV['SCOUT_MONITOR_INTERVAL'] = '10'
    ENV['SCOUT_MONITOR_INTERVAL_DELAY'] = '10'
    ENV['SCOUT_LOGS_MONITOR'] = 'true'
    ENV['SCOUT_LOGS_CAPTURE_LEVEL'] = 'debug'

    output_from_log = capture_stdout do
      context = ScoutApm::Logging::Context.new
      conf_file = File.expand_path('../data/config_test_1.yml', __dir__)
      conf = ScoutApm::Logging::Config.with_file(context, conf_file)
      context.config = conf

      test_logger = ScoutTestLogger.new($stdout)
      test_logger.level = 'INFO'

      TestLoggerWrapper.logger = test_logger

      capture = ScoutApm::Logging::Loggers::Capture.new(context)
      capture.setup!

      expect(TestLoggerWrapper.logger.class).to eq(ScoutApm::Logging::Loggers::Proxy)

      TestLoggerWrapper.logger.info('TEST')
      TestLoggerWrapper.logger.debug('SHOULD NOT CAPTURE')

      log_path = File.join(context.config.value('logs_proxy_log_dir'), 'test.log')
      content = File.read(log_path)
      expect(content).to include('TEST')

      puts_log_path = File.join(context.config.value('logs_proxy_log_dir'), 'puts.log')

      # Shouldn't capture. While the log_capture_level was set to debug,
      # the original logger instance had a higher log level of info.
      expect(content).not_to include('SHOULD NOT CAPTURE')

      state_file = File.read(context.config.value('monitor_state_file'))
      state_data = JSON.parse(state_file)
      expect(state_data['logs_monitored']).to eq([log_path, puts_log_path])
    end

    expect(output_from_log).to include('TEST')
    expect(output_from_log).not_to include('SHOULD NOT CAPTURE')
  end
end
