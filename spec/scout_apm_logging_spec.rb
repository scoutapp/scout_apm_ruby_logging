# frozen_string_literal: true

require 'spec_helper'

describe ScoutApm::Logging do
  it 'checks the Rails lifecycle for creating the daemon and collector processes' do
    expect(`pgrep otelcol-contrib`).to be_empty
    expect(`pgrep scout_apm_log_monitor`).to be_empty

    ENV['SCOUT_MONITOR_LOGS'] = 'true'
    make_basic_app

    pid_file = ScoutApm::Logging::MonitorManager.instance.context.config.value('monitor_pid_file')

    # Check if the PID file exists
    expect(File.exist?(pid_file)).to be_truthy

    # Read the PID from the PID file
    pid = File.read(pid_file).to_i

    # Check if the process with the stored PID is running
    ScoutApm::Logging::Utils.check_process_livelyness(pid, 'scout_apm_logging_monitor')

    # Give the process time to initialize, download the collector, and start it
    wait_for_process_with_timeout!('otelcol-contrib', 20)

    # Kill the process and ensure PID file clean up
    Process.kill('TERM', pid)
    sleep 1 # Give the process time to exit
    expect(File.exist?(pid_file)).to be_falsey
    Process.kill('TERM', `pgrep otelcol-contrib`.to_i)
    sleep 1 # Give the process time to exit
    ENV.delete('SCOUT_MONITOR_LOGS')

    expect(`pgrep otelcol-contrib`).to be_empty
    expect(`pgrep scout_apm_log_monitor`).to be_empty
  end
end
