require 'spec_helper'

require_relative '../../../lib/scout_apm/logging/monitor/monitor'

describe ScoutApm::Logging::Monitor do
  it "Should not restart the collector if the state hasn't changed" do
    ENV['SCOUT_MONITOR_INTERVAL'] = '10'
    ENV['SCOUT_MONITOR_INTERVAL_DELAY'] = '10'
    ENV['SCOUT_LOGS_MONITOR'] = 'true'
    ENV['SCOUT_LOGS_MONITORED'] = '["/tmp/test.log"]'

    context = ScoutApm::Logging::MonitorManager.instance.context
    collector_pid_location = context.config.value('collector_pid_file')
    ScoutApm::Logging::MonitorManager.instance.context.logger.info "Time start: #{Time.now}"
    ScoutApm::Logging::MonitorManager.instance.setup!
    ScoutApm::Logging::MonitorManager.instance.context.logger.info "Time after setup: #{Time.now}"
    # Give the process time to initialize, download the collector, and start it
    wait_for_process_with_timeout!('otelcol-contrib', 20)

    expect(`pgrep otelcol-contrib --runstates D,R,S`).not_to be_empty
    collector_pid = File.read(collector_pid_location)

    # Give time for the monitor interval to run.
    sleep 30

    expect(`pgrep otelcol-contrib --runstates D,R,S`).not_to be_empty
    second_read_pid = File.read(collector_pid_location)

    expect(second_read_pid).to eq(collector_pid)
  end
end
