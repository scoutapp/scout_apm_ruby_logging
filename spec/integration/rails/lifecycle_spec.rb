require 'spec_helper'
require_relative '../../rails/app'

describe ScoutApm::Logging do
  it 'checks the Rails lifecycle for creating the daemon and collector processes' do
    ENV['SCOUT_LOGS_MONITOR'] = 'true'

    context = ScoutApm::Logging::Context.new
    context.config = ScoutApm::Logging::Config.with_file(context, context.config.value('config_file'))

    rails_pid = fork do
      initialize_app
    end

    # TODO: Improve check to wait for Rails initialization.
    sleep 5

    # Call the app to generate the logs
    `curl localhost:8080`

    proxy_dir = context.config.value('logs_proxy_log_dir')
    files = Dir.entries(proxy_dir) - ['.', '..']
    log_file = File.join(proxy_dir, files[0])

    lines = []
    File.open(log_file, 'r') do |file|
      file.each_line do |line|
        # Parse each line as JSON
        lines << JSON.parse(line)
      rescue JSON::ParserError => e
        puts e
      end
    end

    messages = lines.map { |item| item['msg'] }

    # Verify we have all the logs
    expect(messages.count('[TEST] Some log')).to eq(1)
    expect(messages.count('[YIELD] Yield Test')).to eq(1)
    expect(messages.count('Another Log')).to eq(1)
    expect(messages.count('Should not be captured')).to eq(0)

    log_locations = lines.map { |item| item['log_location'] }.compact

    # Verify that log attributes aren't persisted
    expect(log_locations.size).to eq(1)

    # Kill the rails process. We use kill as using any other signal throws a long log line.
    Process.kill('KILL', rails_pid)
  end
end
