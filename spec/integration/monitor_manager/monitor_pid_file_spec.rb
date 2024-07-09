require 'spec_helper'

require_relative '../../../lib/scout_apm/logging/monitor/collector/manager'

describe ScoutApm::Logging::Collector::Manager do
  it 'should recreate the monitor process if monitor.pid file is errant' do
    ENV['SCOUT_MONITOR_LOGS'] = 'true'
    ENV['SCOUT_MONITORED_LOGS'] = '["/tmp/test.log"]'

    ScoutApm::Logging::Utils.ensure_directory_exists('/tmp/scout_apm/scout_apm_log_monitor.pid')

    # A high enough number to not be a PID of a running process
    pid_file_path = '/tmp/scout_apm/scout_apm_log_monitor.pid'
    File.open(pid_file_path, 'w') do |file|
      file.write('123456')
    end

    ScoutApm::Logging::MonitorManager.instance.setup!

    # Give the process time to initialize, download the collector, and start it
    wait_for_process_with_timeout!('otelcol-contrib', 20)

    new_pid = File.read(pid_file_path).to_i

    expect(new_pid).not_to eq(12_345)

    # Check if the process with the stored PID is running
    expect(Process.kill(0, new_pid)).to be_truthy
    ENV.delete('SCOUT_MONITOR_LOGS')

    # Kill the process and ensure PID file clean up
    Process.kill('TERM', new_pid)
    Process.kill('TERM', `pgrep otelcol-contrib --runstates D,R,S`.to_i)
    sleep 1 # Give the process time to exit
  end
end
