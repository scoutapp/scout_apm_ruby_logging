require 'spec_helper'

require_relative '../../../lib/scout_apm/logging/monitor/monitor'

describe ScoutApm::Logging::Monitor do
  it 'should recreate collector process on healthcheck if it has exited' do
    expect(`pgrep otelcol-contrib`).to be_empty
    expect(`pgrep scout_apm_log_monitor`).to be_empty
  
    ScoutApm::Logging::Utils.ensure_directory_exists('/tmp/scout_apm/scout_apm_log_monitor.pid')

    ScoutApm::Logging::MonitorManager.instance.setup!
    sleep 10 # Give the manager time to initialize, download the collector, and start it
    collector_process_id = `pgrep otelcol-contrib`
    expect(collector_process_id).not_to be_empty

    Process.kill('TERM', collector_process_id.to_i)

    sleep 15 # Give the process time to exit, and for the healthcheck to restart it
    new_collector_process_id = `pgrep otelcol-contrib`
    expect(new_collector_process_id).not_to be_empty
    expect(new_collector_process_id).not_to eq(collector_process_id)

    # Cleanup the monitoring of the collector process
    Process.kill('TERM', File.read('/tmp/scout_apm/scout_apm_log_monitor.pid').to_i)
    sleep 1
    Process.kill('TERM', new_collector_process_id.to_i)
    
    sleep 1 # Give the process time to exit
    expect(`pgrep otelcol-contrib`).to be_empty
    expect(`pgrep scout_apm_log_monitor`).to be_empty
  end
end
