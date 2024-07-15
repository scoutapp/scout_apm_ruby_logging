require 'spec_helper'

describe ScoutApm::Logging do
  it 'checks the Rails lifecycle for creating the daemon and collector processes' do
    ENV['SCOUT_LOGS_MONITOR'] = 'true'
    ENV['SCOUT_LOGS_MONITORED'] = '["/tmp/test.log"]'

    pid_file = ScoutApm::Logging::MonitorManager.instance.context.config.value('monitor_pid_file')
    expect(File.exist?(pid_file)).to be_falsey

    make_basic_app

    wait_for_process_with_timeout!('otelcol-contrib', 20)

    # Check if the monitor PID file exists
    expect(File.exist?(pid_file)).to be_truthy

    # Read the PID from the PID file
    pid = File.read(pid_file).to_i

    # Check if the process with the stored PID is running
    expect(ScoutApm::Logging::Utils.check_process_liveliness(pid, 'scout_apm_logging_monitor')).to be_truthy

    # Kill the process and ensure PID file clean up
    Process.kill('TERM', pid)
    sleep 1 # Give the process time to exit
    expect(File.exist?(pid_file)).to be_falsey
  end
end
