require 'yaml'

require 'spec_helper'

require_relative '../../../../lib/scout_apm/logging/monitor/collector/configuration'

describe ScoutApm::Logging::Collector::Configuration do
  it 'creates the correct configuration for the otelcol' do
    context = ScoutApm::Logging::Context.new
    setup_collector_config!(context)

    expect(File.exist?(context.config.value('collector_config_file'))).to be_truthy
    config = YAML.load_file(context.config.value('collector_config_file'))

    expect(config['exporters']['otlp']['endpoint']).to eq('https://otlp.telemetryhub.com:4317')
    expect(config['exporters']['otlp']['headers']['x-telemetryhub-key']).to eq('00001000010000abc')
    expect(config['receivers']['filelog']['include']).to eq(['/tmp/fake_log_file.log'])
  end

  it 'merges in a logs config correctly' do
    ENV['SCOUT_LOGS_CONFIG'] = File.expand_path('../../../data/logs_config.yml', __dir__)

    context = ScoutApm::Logging::Context.new
    setup_collector_config!(context)

    expect(File.exist?(context.config.value('collector_config_file'))).to be_truthy
    config = YAML.load_file(context.config.value('collector_config_file'))

    expect(config['exporters']['otlp']['endpoint']).to eq('https://otlp.telemetryhub.com:4317')
    expect(config['exporters']['otlp']['headers']['x-telemetryhub-key']).to eq('00001000010000abc')
    expect(config['receivers']['filelog']['include']).to eq(['/tmp/fake_log_file.log'])

    # Verify merge and consistent keys
    expect(config['extensions']['file_storage/otc']['directory']).to eq('/dev/null')
    expect(config['extensions']['file_storage/otc']['timeout']).to eq('10s')
  end

  it 'handles an empty logs config file well' do
    ENV['SCOUT_LOGS_CONFIG'] = File.expand_path('../../../data/empty_logs_config.yml', __dir__)

    context = ScoutApm::Logging::Context.new
    setup_collector_config!(context)

    expect(File.exist?(context.config.value('collector_config_file'))).to be_truthy
    config = YAML.load_file(context.config.value('collector_config_file'))

    expect(config['exporters']['otlp']['endpoint']).to eq('https://otlp.telemetryhub.com:4317')
    expect(config['exporters']['otlp']['headers']['x-telemetryhub-key']).to eq('00001000010000abc')
    expect(config['receivers']['filelog']['include']).to eq(['/tmp/fake_log_file.log'])
  end

  private

  def setup_collector_config!(context)
    ENV['SCOUT_MONITOR_STATE_FILE'] = File.expand_path('../../../data/state_file.json', __dir__)
    conf_file = File.expand_path('../../../data/mock_config.yml', __dir__)
    context.config = ScoutApm::Logging::Config.with_file(context, conf_file)

    ScoutApm::Logging::Utils.ensure_directory_exists(context.config.value('collector_config_file'))

    collector_config = ScoutApm::Logging::Collector::Configuration.new(context)
    collector_config.setup!
  end
end
