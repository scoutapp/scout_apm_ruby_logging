require 'spec_helper'

require_relative '../../../lib/scout_apm/logging/monitor/collector/manager'

describe ScoutApm::Logging::Collector::Manager do
  it 'should recreate monitor process if monitor.pid file is errant' do
    ScoutApm::Logging::Utils.ensure_directory_exists('/tmp/scout_apm/scout_apm_log_monitor.pid')

    pid_file_path = '/tmp/scout_apm/scout_apm_log_monitor.pid'
    File.open(pid_file_path, 'w') do |file|
      file.write('12345')
    end

    ScoutApm::Logging::MonitorManager.instance.setup!

    sleep 10 # Give the manager time to initialize, download the collector, and start it

    new_pid = File.read(pid_file_path).to_i

    expect(new_pid).not_to eq(12_345)

    # Check if the process with the stored PID is running
    expect(Process.kill(0, new_pid)).to be_truthy

    ## Clean up the processes
    Process.kill('TERM', new_pid)
    sleep 1
    Process.kill('TERM', `pgrep otelcol-contrib`.to_i)
    sleep 1
  end
end
