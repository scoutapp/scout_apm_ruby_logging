require 'spec_helper'

require_relative '../../../lib/scout_apm/logging/monitor/monitor'

describe ScoutApm::Logging::Monitor do
  it 'should recreate collector process on healthcheck if it has exited' do
    ENV['SCOUT_MONITOR_INTERVAL'] = '10'
    ENV['SCOUT_MONITOR_INTERVAL_DELAY'] = '10'
    ENV['SCOUT_LOGS_MONITOR'] = 'true'
    ENV['SCOUT_LOGS_MONITORED'] = '["/tmp/test.log"]'

    ScoutApm::Logging::Utils.ensure_directory_exists('/tmp/scout_apm/scout_apm_log_monitor.pid')

    ScoutApm::Logging::MonitorManager.instance.setup!

    # Give the process time to initialize, download the collector, and start it
    wait_for_process_with_timeout!('otelcol-contrib', 20)

    expect(`pgrep otelcol-contrib --runstates D,R,S`).not_to be_empty

    # Bypass gracefull shutdown
    `pkill -9 otelcol-contrib`

    # Give the process time to exit, and for the healthcheck to restart it
    wait_for_process_with_timeout!('otelcol-contrib', 30)
  end
end
