# frozen_string_literal: true

require 'spec_helper'

describe ScoutApm::Logging do
  before(:all) do
    # Run the Railtie initializers to trigger the daemon spawning
    make_basic_app
  end

  it 'checks the Rails lifecycle for creating the daemon and collector processes' do
    pid_file = ScoutApm::Logging::MonitorManager.instance.context.config.value('monitor_pid_file')

    # Check if the PID file exists
    expect(File.exist?(pid_file)).to be_truthy

    # Read the PID from the PID file
    pid = File.read(pid_file).to_i

    # Check if the process with the stored PID is running
    ScoutApm::Logging::Utils.check_process_livelyness(pid, 'scout_apm_logging_monitor')

    sleep 10 # Give the process time to initialize, download the collector, and start it
    expect(`pgrep otelcol-contrib`).not_to be_empty

    # Kill the process and ensure PID file clean up
    Process.kill('TERM', pid)
    sleep 1 # Give the process time to exit
    expect(File.exist?(pid_file)).to be_falsey
    Process.kill('TERM', `pgrep otelcol-contrib`.to_i)
    sleep 1 # Give the process time to exit
  end
end
