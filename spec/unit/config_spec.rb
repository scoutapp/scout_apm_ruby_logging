require 'spec_helper'

describe ScoutApm::Logging::Config do
  it 'loads the config file' do
    context = ScoutApm::Logging::Context.new
    conf_file = File.expand_path('../data/config_test_1.yml', __dir__)
    conf = ScoutApm::Logging::Config.with_file(context, conf_file)

    expect(conf.value('log_level')).to eq('debug')
    expect(conf.value('monitor_logs')).to eq(true)
    expect(conf.value('monitor_pid_file')).to eq('/tmp/scout_apm/scout_apm_log_monitor.pid')
    expect(conf.value('logging_ingest_key')).to eq('00001000010000abc')
    expect(conf.value('monitored_logs')).to eq(['/tmp/fake_log_file.log'])
  end

  it 'loads the state file into the config' do
    ENV['SCOUT_MONITOR_STATE_FILE'] = File.expand_path('../data/state_file.json', __dir__)

    context = ScoutApm::Logging::Context.new
    conf_file = File.expand_path('../data/config_test_1.yml', __dir__)
    conf = ScoutApm::Logging::Config.with_file(context, conf_file)

    expect(conf.value('health_check_port')).to eq(1234)
  end
end
