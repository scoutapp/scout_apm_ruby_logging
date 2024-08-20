require 'spec_helper'
require_relative '../../rails/app'

describe ScoutApm::Logging do
  it 'checks the Rails lifecycle for creating the daemon and collector processes' do
    ENV['SCOUT_LOGS_MONITOR'] = 'true'

    context = ScoutApm::Logging::MonitorManager.instance.context
    pid_file = context.config.value('monitor_pid_file')
    expect(File.exist?(pid_file)).to be_falsey

    rails_pid = fork do
      initialize_app
    end

    wait_for_process_with_timeout!('otelcol-contrib', 20)

    # Check if the monitor PID file exists
    expect(File.exist?(pid_file)).to be_truthy

    # Read the PID from the PID file
    pid = File.read(pid_file).to_i

    # Check if the process with the stored PID is running
    expect(ScoutApm::Logging::Utils.check_process_liveliness(pid, 'scout_apm_logging_monitor')).to be_truthy

    # Call the app to generate the logs
    `curl localhost:8080`

    proxy_dir = context.config.value('logs_proxy_log_dir')
    files = Dir.entries(proxy_dir) - ['.', '..']
    base_log_file = files.find { |file| !file.include?('puts') }
    log_file = File.join(proxy_dir, base_log_file)
    messages = get_log_messages(log_file)

    # Verify we have all the logs
    expect(messages.count('[TEST] Some log')).to eq(1)
    expect(messages.count('[YIELD] Yield Test')).to eq(1)
    expect(messages.count('Another Log')).to eq(1)
    expect(messages.count('Should not be captured')).to eq(0)

    log_locations = get_lines(log_file).map { |item| item['log_location'] }.compact
    # Verify that log attributes aren't persisted
    expect(log_locations.size).to eq(1)

    base_puts_log_file = files.find { |file| file.include?('puts') }
    puts_log_file = File.join(proxy_dir, base_puts_log_file)
    puts_messages = get_log_messages(puts_log_file)

    expect(puts_messages.count('A puts log')).to eq(1)

    # Kill the rails process. We use kill as using any other signal throws a long log line.
    Process.kill('KILL', rails_pid)
    # Kill the process and ensure PID file clean up
    Process.kill('TERM', pid)
    sleep 1 # Give the process time to exit
    expect(File.exist?(pid_file)).to be_falsey
  end

  private

  def get_lines(log_file)
    lines = []
    File.open(log_file, 'r') do |file|
      file.each_line do |line|
        # Parse each line as JSON
        lines << JSON.parse(line)
      rescue JSON::ParserError => e
        puts e
      end
    end
    lines
  end

  def get_log_messages(log_file)
    lines = get_lines(log_file)
    lines.map { |item| item['msg'] }
  end
end
