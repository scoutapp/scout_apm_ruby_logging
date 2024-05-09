require 'spec_helper'

require_relative '../../../lib/scout_apm/logging/monitor/collector/manager'

describe ScoutApm::Logging::Collector::Manager do
  it 'should recreate monitor process if monitor.pid file is errant' do
    ScoutApm::Logging::Utils.ensure_directory_exists('/tmp/scout_apm/scout_apm_log_monitor.pid')

    pid_file_path = '/tmp/scout_apm/scout_apm_log_monitor.pid'
    File.open(pid_file_path, 'w') do |file|
      file.write('12345')
    end

    # Stub out the IO.pipe and Process.spawn calls
    reader_mock = double('Reader')
    writer_mock = double('Writer')

    allow(reader_mock).to receive(:gets).and_return('mocked_input')
    allow(reader_mock).to receive(:close)
    allow(writer_mock).to receive(:close)
    expect(writer_mock).to receive(:puts)

    allow(IO).to receive(:pipe).and_return([reader_mock, writer_mock])
    allow(Process).to receive(:spawn).exactly(1)

    ScoutApm::Logging::MonitorManager.instance.setup!

    new_pid = File.read(pid_file_path).to_i

    expect(new_pid).not_to eq(12_345)

    # Check if the process with the stored PID is running
    expect(Process.kill(0, new_pid)).to be_truthy
  end
end
