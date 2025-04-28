require 'webmock/rspec'

require 'spec_helper'
require 'zlib'
require 'stringio'
require_relative '../../rails/app'

ScoutApm::Logging::Loggers::FileLogger.class_exec do
  define_method(:filter_log_location) do |locations|
    locations.find { |loc| loc.path.include?(Rails.root.to_s) && !loc.path.include?('scout_apm/logging') }
  end
end

describe ScoutApm::Logging do
  before do
    @file_path = '/app/response_body.txt'
    # Capture the outgoing HTTP request to inspect its values
    stub_request(:post, 'https://otlp-devel.scoutotel.com:4318/v1/logs')
      .to_return do |request|
        # We have to write to the file, as we are applying the patch in the fork, and
        # need to run the expectations in the main process.
        File.open(@file_path, 'a+') do |file|
          msgs = transform_body_to_msgs(request.body)
          file.puts(msgs)
        end
        { body: '', headers: {}, status: 200 }
      end
  end

  it 'checks the Rails lifecycle for creating the daemon and collector processes' do
    ENV['SCOUT_LOGS_MONITOR'] = 'true'
    ENV['SCOUT_LOGS_REPORTING_ENDPOINT_HTTP'] = 'https://otlp-devel.scoutotel.com:4318/v1/logs'

    context = ScoutApm::Logging::Context.new
    context.config = ScoutApm::Logging::Config.with_file(context, context.config.value('config_file'))

    rails_pid = fork do
      initialize_app
    end

    # TODO: Improve check to wait for Rails initialization.
    sleep 5

    # Call the app to generate the logs
    `curl localhost:9292`

    sleep 5

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

    local_messages = lines.map { |item| item['msg'] }
    puts local_messages

    # Verify we have all the logs in the local log file
    expect(local_messages.count('[TEST] Some log')).to eq(1)
    expect(local_messages.count('[YIELD] Yield Test')).to eq(1)
    expect(local_messages.count('Another Log')).to eq(1)
    expect(local_messages.count('Should not be captured')).to eq(0)
    expect(local_messages.count('Warn level log')).to eq(1)
    expect(local_messages.count('Error level log')).to eq(1)
    expect(local_messages.count('Fatal level log')).to eq(1)

    # Verify the logs are sent to the receiver
    receiver_contents = File.readlines(@file_path, chomp: true)
    expect(receiver_contents.count('[TEST] Some log')).to eq(1)
    expect(receiver_contents.count('[YIELD] Yield Test')).to eq(1)
    expect(receiver_contents.count('Another Log')).to eq(1)
    expect(receiver_contents.count('Should not be captured')).to eq(0)
    expect(local_messages.count('Warn level log')).to eq(1)
    expect(local_messages.count('Error level log')).to eq(1)
    expect(local_messages.count('Fatal level log')).to eq(1)

    # Kill the rails process. We use kill as using any other signal throws a long log line.
    Process.kill('KILL', rails_pid)
  end

  private

  def transform_body_to_msgs(body)
    gz = Zlib::GzipReader.new(StringIO.new(body))
    uncompressed = gz.read

    value = ::Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest.decode(uncompressed)
    value_hash = value.to_h

    value_hash[:resource_logs].map do |item|
      item[:scope_logs].map do |sl|
        sl[:log_records].map do |log|
          log[:body][:string_value]
        end
      end
    end.flatten
  end
end
