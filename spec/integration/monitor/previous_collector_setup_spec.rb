require 'spec_helper'

require_relative '../../../lib/scout_apm/logging/monitor/monitor'

describe ScoutApm::Logging::Monitor do
  it 'should use previous collector setup if monitor daemon exits' do
    ENV['SCOUT_MONITOR_LOGS'] = 'true'
    ENV['SCOUT_MONITORED_LOGS'] = '["/tmp/test.log"]'

    monitor_pid_location = ScoutApm::Logging::MonitorManager.instance.context.config.value('monitor_pid_file')
    collector_pid_location = ScoutApm::Logging::MonitorManager.instance.context.config.value('collector_pid_file')
    ScoutApm::Logging::Utils.ensure_directory_exists(monitor_pid_location)

    ScoutApm::Logging::MonitorManager.instance.setup!
    # Give the process time to initialize, download the collector, and start it
    wait_for_process_with_timeout!('otelcol-contrib', 20)

    monitor_pid = File.read(monitor_pid_location)

    otelcol_pid = `pgrep otelcol-contrib --runstates D,R,S`.strip!
    stored_otelcol_pid = File.read(collector_pid_location)
    expect(otelcol_pid).to eq(stored_otelcol_pid)

    `kill -9 #{monitor_pid}`

    # Create a separate monitor manager instance, or else we won't reload
    # the configuraiton state.
    ScoutApm::Logging::MonitorManager.new.setup!

    sleep 5

    expect(`pgrep -f /app/bin/scout_apm_logging_monitor --runstates D,R,S`).not_to be_empty

    new_monitor_pid = File.read(monitor_pid_location)
    expect(new_monitor_pid).not_to eq(monitor_pid)

    should_be_same_otelcol_pid = `pgrep otelcol-contrib --runstates D,R,S`.strip!
    should_be_same_stored_otelcol_pid = File.read(collector_pid_location)
    expect(should_be_same_otelcol_pid).to eq(otelcol_pid)
    expect(should_be_same_stored_otelcol_pid).to eq(stored_otelcol_pid)
  end
end
