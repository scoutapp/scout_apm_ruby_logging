# This is really meant to simulate multiple processes calling the MonitorManager setup.
# Trying to create **multiple fake** rails environments is a bit challening 
# (such as a rails app and a couple rails runners).

# See: https://github.com/rails/rails/blob/6d126e03dbbf5d30fa97b580f7dee46343537b7b/railties/test/isolation/abstract_unit.rb#L339

# We simulate the ultimate outcome here -- ie Railtie invoking the setup.
require 'spec_helper'

require 'pry'

describe ScoutApm::Logging do
  it 'Should only create a single monitor daemon if manager is called multiple times' do
    ENV['SCOUT_MONITOR_LOGS'] = 'true'

    pid_file = ScoutApm::Logging::MonitorManager.instance.context.config.value('monitor_pid_file')
    expect(File.exist?(pid_file)).to be_falsey

    ScoutApm::Logging::MonitorManager.instance.setup!

    expect(File.exist?(pid_file)).to be_truthy
    original_pid = File.read(pid_file).to_i
    expect(ScoutApm::Logging::Utils.check_process_liveliness(original_pid, 'scout_apm_logging_monitor')).to be_truthy

    ScoutApm::Logging::MonitorManager.instance.setup!
    expect(File.exist?(pid_file)).to be_truthy
    updated_pid = File.read(pid_file).to_i
    expect(updated_pid).to eq(original_pid)
    expect(ScoutApm::Logging::Utils.check_process_liveliness(original_pid, 'scout_apm_logging_monitor')).to be_truthy
  end
end
