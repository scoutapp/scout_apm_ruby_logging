require 'spec_helper'

require_relative '../../../../../lib/scout_apm/logging/monitor/collector/downloader'

describe ScoutApm::Logging::Collector::Downloader do
  it 'should validate checksum, and correct download if neccessary' do
    ENV['SCOUT_LOGS_MONITOR'] = 'true'
    ENV['SCOUT_LOGS_MONITORED'] = '["/tmp/test.log"]'

    otelcol_contrib_path = '/tmp/scout_apm/otelcol-contrib'
    ScoutApm::Logging::Utils.ensure_directory_exists(otelcol_contrib_path)

    File.write(otelcol_contrib_path, 'fake content')

    ScoutApm::Logging::MonitorManager.instance.setup!

    # Give the process time to initialize, download the collector, and start it
    wait_for_process_with_timeout!('otelcol-contrib', 20)

    download_time = File.mtime(otelcol_contrib_path)

    expect(`pgrep otelcol-contrib --runstates D,R,S`).not_to be_empty

    ENV['SCOUT_LOGS_MONITOR'] = 'false'

    ScoutApm::Logging::MonitorManager.new.setup!

    sleep 5 # Give the process time to exit

    expect(File.exist?(ScoutApm::Logging::MonitorManager.instance.context.config.value('monitor_pid_file'))).to be_falsey
    expect(`pgrep otelcol-contrib --runstates D,R,S`).to be_empty
    expect(`pgrep scout_apm_log_monitor --runstates D,R,S`).to be_empty

    ENV['SCOUT_LOGS_MONITOR'] = 'true'

    ScoutApm::Logging::MonitorManager.new.setup!

    # Give the process time to exit, and for the healthcheck to restart it
    wait_for_process_with_timeout!('otelcol-contrib', 30)

    expect(`pgrep otelcol-contrib --runstates D,R,S`).not_to be_empty

    recheck_time = File.mtime(otelcol_contrib_path)

    expect(download_time).to eq(recheck_time)
  end
end
