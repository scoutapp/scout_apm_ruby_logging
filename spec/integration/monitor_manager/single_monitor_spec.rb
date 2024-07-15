# This is really meant to simulate multiple processes calling the MonitorManager setup.
# Trying to create **multiple fake** rails environments is a bit challening
# (such as a rails app and a couple rails runners).

# See: https://github.com/rails/rails/blob/6d126e03dbbf5d30fa97b580f7dee46343537b7b/railties/test/isolation/abstract_unit.rb#L339

# We simulate the ultimate outcome here -- ie Railtie invoking the setup.
require 'spec_helper'

describe ScoutApm::Logging do
  it 'Should only create a single monitor daemon if manager is called multiple times' do
    ENV['SCOUT_LOGS_MONITOR'] = 'true'
    ENV['SCOUT_LOGS_MONITORED'] = '["/tmp/test.log"]'

    pid_file = ScoutApm::Logging::MonitorManager.instance.context.config.value('monitor_pid_file')
    expect(File.exist?(pid_file)).to be_falsey

    context = ScoutApm::Logging::MonitorManager.instance.context

    pids = 3.times.map do
      fork do
        puts 'fork attempting to gain lock'
        ScoutApm::Logging::Utils.attempt_exclusive_lock(context) do
          puts 'obtained lock'
          ScoutApm::Logging::MonitorManager.new.setup!
        end
      end
    end

    pids.each { |pid| Process.wait(pid) }

    wait_for_process_with_timeout!('otelcol-contrib', 20)

    # The file lock really should be gone at this point.
    expect(File.exist?(context.config.value('manager_lock_file'))).to be_falsey
    expect(File.exist?(pid_file)).to be_truthy

    original_pid = File.read(pid_file).to_i
    expect(ScoutApm::Logging::Utils.check_process_liveliness(original_pid, 'scout_apm_logging_monitor')).to be_truthy

    # Another process comes in and tries to start it again
    ScoutApm::Logging::Utils.attempt_exclusive_lock(context) do
      puts 'obtained lock later on'
      ScoutApm::Logging::MonitorManager.new.setup!
    end

    expect(File.exist?(context.config.value('manager_lock_file'))).to be_falsey
    expect(File.exist?(pid_file)).to be_truthy
    updated_pid = File.read(pid_file).to_i
    expect(updated_pid).to eq(original_pid)
    expect(ScoutApm::Logging::Utils.check_process_liveliness(original_pid, 'scout_apm_logging_monitor')).to be_truthy
  end
end
