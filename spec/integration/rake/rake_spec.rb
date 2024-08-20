require_relative '../../rails/app'

require 'spec_helper'
require 'rake'

describe ScoutApm::Logging do
  it 'runs the rake task and captures the logs' do
    ENV['SCOUT_LOGS_MONITOR'] = 'true'

    context = ScoutApm::Logging::MonitorManager.instance.context

    App.initialize!

    contents = <<~RUBY
      namespace :test do
        task log_test: :environment do
          Rails.logger.info "Hello"
          Rails.logger.debug "Should not capture"
          puts "Puts log"
        end
      end
    RUBY

    write_to_app_path('lib/tasks/test_task.rake', contents)
    Rake.add_rakelib '/app/lib/tasks'

    Rails.application.load_tasks

    Rake::Task['test:log_test'].invoke

    wait_for_process_with_timeout!('otelcol-contrib', 20)

    proxy_dir = context.config.value('logs_proxy_log_dir')
    files = Dir.entries(proxy_dir) - ['.', '..']
    base_log_file = files.find { |file| !file.include?('puts') }
    log_file = File.join(proxy_dir, base_log_file)
    messages = get_messages(log_file)

    # Verify we have all the logs
    expect(messages.count('Hello')).to eq(1)
    expect(messages.count('Should not capture')).to eq(0)

    base_puts_log_file = files.find { |file| file.include?('puts') }
    puts_log_file = File.join(proxy_dir, base_puts_log_file)
    puts_mesages = get_messages(puts_log_file)

    expect(puts_mesages.count('Puts log')).to eq(1)
  end

  private

  def write_to_app_path(path, contents, mode = 'w')
    file_name = "#{Rails.root}/#{path}"
    FileUtils.mkdir_p File.dirname(file_name)
    File.open(file_name, mode) do |f|
      f.puts contents
    end
    file_name
  end

  def get_messages(log_file)
    lines = []
    File.open(log_file, 'r') do |file|
      file.each_line do |line|
        # Parse each line as JSON
        lines << JSON.parse(line)
      rescue JSON::ParserError => e
        puts e
      end
    end
    lines.map { |item| item['msg'] }
  end
end
