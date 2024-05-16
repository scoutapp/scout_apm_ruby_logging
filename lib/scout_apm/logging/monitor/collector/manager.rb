# frozen_string_literal: true

require_relative './checksum'
require_relative './configuration'
require_relative './downloader'

module ScoutApm
  module Logging
    module Collector
      # Manager class for the downloading, configuring, and starting of the collector.
      class Manager
        attr_reader :context

        def initialize(context)
          @context = context
        end

        def setup!
          Configuration.new(context).setup!
          Downloader.new(context).run!

          start_collector if Checksum.new(context).verified_checksum?(should_log_failures: true)
        end

        def start_collector
          context.logger.info('Starting otelcol-contrib')
          collector_process = Process.spawn("#{extracted_collector_path}/otelcol-contrib --config #{config_file}")
          File.write(context.config.value('collector_pid_file'), collector_process)
        end

        private

        def extracted_collector_path
          context.config.value('collector_download_dir')
        end

        def config_file
          context.config.value('collector_config_file')
        end
      end
    end
  end
end
