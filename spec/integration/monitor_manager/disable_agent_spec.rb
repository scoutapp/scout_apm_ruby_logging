require 'spec_helper'

require_relative '../../../lib/scout_apm/logging/monitor/collector/manager'

describe ScoutApm::Logging::Collector::Manager do
  it 'If monitor is false, it should remove the daemon and collector process if they are present' do
    ENV['SCOUT_LOGS_MONITOR'] = 'true'
    ENV['SCOUT_LOGS_MONITORED'] = '["/tmp/test.log"]'

    expect(`pgrep otelcol-contrib --runstates D,R,S`).to be_empty

    ScoutApm::Logging::MonitorManager.instance.context.logger.info "Time start: #{Time.now}"
    ScoutApm::Logging::MonitorManager.instance.setup!
    ScoutApm::Logging::MonitorManager.instance.context.logger.info "Time after setup: #{Time.now}"

    wait_for_process_with_timeout!('otelcol-contrib', 20)

    ENV['SCOUT_LOGS_MONITOR'] = 'false'

    ScoutApm::Logging::MonitorManager.new.setup!

    sleep 5 # Give the process time to exit

    expect(File.exist?(ScoutApm::Logging::MonitorManager.instance.context.config.value('monitor_pid_file'))).to be_falsey
    expect(`pgrep otelcol-contrib --runstates D,R,S`).to be_empty
    expect(`pgrep scout_apm_log_monitor --runstates D,R,S`).to be_empty

    ENV.delete('SCOUT_LOGS_MONITOR')
  end
end
