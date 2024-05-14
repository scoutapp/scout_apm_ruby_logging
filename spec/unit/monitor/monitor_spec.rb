require 'spec_helper'

require_relative '../../../lib/scout_apm/logging/monitor/monitor'

describe ScoutApm::Logging::Monitor do
  it 'should recreate collector process on healthcheck if it has exited' do
    ScoutApm::Logging::Utils.ensure_directory_exists('/tmp/scout_apm/scout_apm_log_monitor.pid')
    File.write('/tmp/fake_log_file.log', 'fake log file')
    File.write('/tmp/scout_apm/scout_apm_log_monitor.pid', '12345')

    conf_file = File.expand_path('../../data/mock_config.yml', __dir__)

    monitor = ScoutApm::Logging::Monitor.new
    config = ScoutApm::Logging::Config.with_file(monitor.context, conf_file)
    monitor.config = config

    # Move to thread as we are in a loop
    monitor_thread = Thread.new do
      monitor.setup!
    end

    sleep 10 # Give the manager time to initialize, download the collector, and start it
    collector_process_id = `pgrep otelcol-contrib`
    expect(collector_process_id).not_to be_empty

    Process.kill('TERM', collector_process_id.to_i)

    sleep 15 # Give the process time to exit, and for the healthcheck to restart it
    new_collector_process_id = `pgrep otelcol-contrib`
    expect(new_collector_process_id).not_to be_empty
    expect(new_collector_process_id).not_to eq(collector_process_id)

    # Cleanup the monitoring of the collector process
    monitor.stop!
    monitor_thread.join(0.1)
    Process.kill('TERM', new_collector_process_id.to_i)
  end
end
