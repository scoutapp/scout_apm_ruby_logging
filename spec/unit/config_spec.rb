require 'spec_helper'

describe ScoutApm::Logging::Config do
  it 'loads the config file' do
    context = ScoutApm::Logging::Context.new
    conf_file = File.expand_path('../data/config_test_1.yml', __dir__)
    conf = ScoutApm::Logging::Config.with_file(context, conf_file)

    expect(conf.value('log_level')).to eq('debug')
    expect(conf.value('logging_monitor')).to eq(true)
    expect(conf.value('monitor_pid_file')).to eq('/tmp/scout_apm_log_monitor.pid')
    expect(conf.value('logging_ingest_key')).to eq('00001000010000')
  end
end
