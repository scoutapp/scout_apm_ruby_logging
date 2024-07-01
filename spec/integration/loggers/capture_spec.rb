require 'logger'

require 'spec_helper'

describe ScoutApm::Logging::Loggers::Capture do
  it 'should find the logger, capture the log destination, and rotate collector configs' do
    ENV['SCOUT_MONITOR_INTERVAL'] = '10'
    ENV['SCOUT_DELAY_FIRST_HEALTHCHECK'] = '10'
    ENV['SCOUT_MONITOR_LOGS'] = 'true'

    state_file_location = ScoutApm::Logging::MonitorManager.instance.context.config.value('monitor_state_file')
    collector_pid_location = ScoutApm::Logging::MonitorManager.instance.context.config.value('collector_pid_file')
    ScoutApm::Logging::Utils.ensure_directory_exists(state_file_location)

    ScoutTestLogger.new('/tmp/first_file.log')

    ScoutApm::Logging::MonitorManager.instance.setup!

    # Give the process time to initialize, download the collector, and start it
    wait_for_process_with_timeout!('otelcol-contrib', 20)

    expect(`pgrep otelcol-contrib --runstates D,R,S`).not_to be_empty
    collector_pid = File.read(collector_pid_location)

    content = File.read(state_file_location)
    data = JSON.parse(content)
    expect(data['monitored_logs']).to eq(['/tmp/first_file.log'])

    ScoutTestLogger.new('/tmp/second_file.log')

    ScoutApm::Logging::MonitorManager.instance.setup!

    content = File.read(state_file_location)
    data = JSON.parse(content)

    expect(data['monitored_logs'].sort).to eq(['/tmp/first_file.log', '/tmp/second_file.log'])

    # Need to wait for the delay first health check, next monitor interval to restart the collector, and then for
    # the collector to restart
    sleep 60

    expect(`pgrep otelcol-contrib --runstates D,R,S`).not_to be_empty
    new_collector_pid = File.read(collector_pid_location)

    # Should have restarted the collector based on the change
    expect(new_collector_pid).not_to eq(collector_pid)
  end
end
