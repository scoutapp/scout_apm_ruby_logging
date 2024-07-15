require 'spec_helper'

describe ScoutApm::Logging::Config do
  it 'flushes and loads the state' do
    context = ScoutApm::Logging::Context.new
    conf_file = File.expand_path('../data/config_test_1.yml', __dir__)
    conf = ScoutApm::Logging::Config.with_file(context, conf_file)

    context.config = conf

    ScoutApm::Logging::Config::ConfigDynamic.set_value('health_check_port', 1234)

    context.config.state.flush_state!

    data = ScoutApm::Logging::Config::State.new(context).load_state_from_file

    expect(data['health_check_port']).to eq(context.config.value('health_check_port'))
    expect(data['logs_monitored']).to eq(context.config.value('logs_monitored'))
  end
end
