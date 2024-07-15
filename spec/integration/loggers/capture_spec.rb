require 'logger'

require 'spec_helper'

describe ScoutApm::Logging::Loggers::Capture do
  it 'should find the logger, capture the log destination, and rotate collector configs' do
    ENV['SCOUT_MONITOR_INTERVAL'] = '10'
    ENV['SCOUT_MONITOR_INTERVAL_DELAY'] = '10'
    ENV['SCOUT_LOGS_MONITOR'] = 'true'

    context = ScoutApm::Logging::MonitorManager.instance.context

    state_file_location = context.config.value('monitor_state_file')
    collector_pid_location = context.config.value('collector_pid_file')
    ScoutApm::Logging::Utils.ensure_directory_exists(state_file_location)

    first_logger = ScoutTestLogger.new('/tmp/first_file.log')
    first_logger_basename = File.basename(first_logger.instance_variable_get(:@logdev).filename.to_s)
    first_logger_updated_path = File.join(context.config.value('logs_proxy_log_dir'), first_logger_basename)

    # While we only use the ObjectSpace for the test logger, we need to wait for it to be captured.
    wait_for_logger

    similuate_railtie

    # Give the process time to initialize, download the collector, and start it
    wait_for_process_with_timeout!('otelcol-contrib', 20)

    expect(`pgrep otelcol-contrib --runstates D,R,S`).not_to be_empty
    collector_pid = File.read(collector_pid_location)

    content = File.read(state_file_location)
    data = JSON.parse(content)
    expect(data['logs_monitored']).to eq([first_logger_updated_path])

    second_logger = ScoutTestLogger.new('/tmp/second_file.log')
    second_logger_basename = File.basename(second_logger.instance_variable_get(:@logdev).filename.to_s)
    second_logger_updated_path = File.join(context.config.value('logs_proxy_log_dir'), second_logger_basename)

    similuate_railtie

    content = File.read(state_file_location)
    data = JSON.parse(content)

    expect(data['logs_monitored'].sort).to eq([first_logger_updated_path, second_logger_updated_path])

    # Need to wait for the delay first health check, next monitor interval to restart the collector, and then for
    # the collector to restart
    sleep 25
    wait_for_process_with_timeout!('otelcol-contrib', 20)

    expect(`pgrep otelcol-contrib --runstates D,R,S`).not_to be_empty
    new_collector_pid = File.read(collector_pid_location)

    # Should have restarted the collector based on the change
    expect(new_collector_pid).not_to eq(collector_pid)
  end

  private

  def similuate_railtie
    context = ScoutApm::Logging::MonitorManager.instance.context

    ScoutApm::Logging::Loggers::Capture.new(context).capture_log_locations!
    ScoutApm::Logging::MonitorManager.new.setup!
  end

  def wait_for_logger
    start_time = Time.now
    loop do
      break if ObjectSpace.each_object(ScoutTestLogger).count.positive?

      raise 'Timed out while waiting for logger in ObjectSpace' if Time.now - start_time > 10

      sleep 0.1
    end
  end
end
