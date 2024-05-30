# frozen_string_literal: true

require_relative './checksum'
require_relative './configuration'
require_relative './downloader'
require_relative './extractor'

module ScoutApm
  module Logging
    module Collector
      # Manager class for the downloading, configuring, and starting of the collector.
      class Manager
        attr_reader :context

        def initialize(context)
          @context = context

          @checksum = Checksum.new(@context)
          @configuration = Configuration.new(@context)
          @downloader = Downloader.new(@context)
          @extractor = Extractor.new(@context)
        end

        def setup!
          @configuration.setup!
          @downloader.download!
          @extractor.extract!

          start_collector if verified_checksum_and_extracted?
        end

        def start_collector
          context.logger.info('Starting otelcol-contrib')
          collector_process = Process.spawn("#{extracted_collector_path}/otelcol-contrib --config #{config_file}")
          File.write(context.config.value('collector_pid_file'), collector_process)
        end

        private

        def verified_checksum_and_extracted?
          has_verfied_checksum = @checksum.verified_checksum?(should_log_failures: true)
          has_extracted_content = @extractor.has_been_extracted?

          has_verfied_checksum && has_extracted_content
        end

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
