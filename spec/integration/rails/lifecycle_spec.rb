require 'webmock/rspec'

# Old, but still works.
require 'action_cable_client'
require 'eventmachine'
require 'spec_helper'
require 'zlib'
require 'stringio'
require 'securerandom'
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
          records = transform_body_to_records(request.body)
          records.each { |record| file.puts(record.to_json) }
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

    channel_client = fork do
      url = 'ws://localhost:9292/cable'
      channel_name = 'TestChannel'
      # Loops.
      EventMachine.run do
        client = ActionCableClient.new(url, channel_name)
        # called whenever a welcome message is received from the server
        client.connected { puts 'successfully connected.' }

        client.subscribed do
          puts 'client subscribed to the channel.'
          client.perform('ding', { message: 'hello from client' })
        end

        # called whenever a message is received from the server
        client.received do |message|
          puts message
        end
      end
    end

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
    receiver_records = File.readlines(@file_path, chomp: true).map { |line| JSON.parse(line) }
    receiver_messages = receiver_records.map { |record| record['body'] }
    expect(receiver_messages.count('[TEST] Some log')).to eq(1)
    expect(receiver_messages.count('[YIELD] Yield Test')).to eq(1)
    expect(receiver_messages.count('Another Log')).to eq(1)
    expect(receiver_messages.count('Should not be captured')).to eq(0)
    expect(receiver_messages.count('Warn level log')).to eq(1)
    expect(receiver_messages.count('Error level log')).to eq(1)
    expect(receiver_messages.count('Fatal level log')).to eq(1)

    # Verify the severity number sent on the wire uses the OpenTelemetry scale,
    # not Ruby's Logger::Severity scale. Guards against upstream exporter drift
    # now that the severity-remapping patch has been removed.
    expect(severity_for(receiver_records, 'Warn level log')).to eq(:SEVERITY_NUMBER_WARN)
    expect(severity_for(receiver_records, 'Error level log')).to eq(:SEVERITY_NUMBER_ERROR)
    expect(severity_for(receiver_records, 'Fatal level log')).to eq(:SEVERITY_NUMBER_FATAL)
    expect(severity_for(receiver_records, '[TEST] Some log')).to eq(:SEVERITY_NUMBER_INFO)

    # Verify we recorded server ActionCable messages
    expect(receiver_messages.count { |msg| msg.include?('ActionCable Connected:') }).to eq(1)
    expect(receiver_messages.count('Subscribed to test_channel')).to eq(1)
    expect(receiver_messages.count { |msg| msg.include?('Ding received with data: {"message"') }).to eq(1)
    expect(local_messages.count { |msg| msg.include?('ActionCable Connected:') }).to eq(1)
    expect(local_messages.count('Subscribed to test_channel')).to eq(1)
    expect(local_messages.count { |msg| msg.include?('Ding received with data: {"message"') }).to eq(1)

    # Kill the rails process. We use kill as using any other signal throws a long log line.
    Process.kill('KILL', rails_pid)
    Process.kill('KILL', channel_client)
  end

  private

  def transform_body_to_records(body) # rubocop:disable Metrics/AbcSize
    gz = Zlib::GzipReader.new(StringIO.new(body))
    uncompressed = gz.read

    value = ::Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest.decode(uncompressed)
    value_hash = value.to_h

    value_hash[:resource_logs].map do |item|
      item[:scope_logs].map do |sl|
        sl[:log_records].map do |log|
          {
            'body' => log[:body][:string_value],
            'severity_number' => log[:severity_number],
            'severity_text' => log[:severity_text]
          }
        end
      end
    end.flatten
  end

  def severity_for(records, body)
    record = records.find { |item| item['body'] == body }
    record && record['severity_number']&.to_sym
  end
end
