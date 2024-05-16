# frozen_string_literal: true

require_relative './configuration'
require_relative './downloader'

module ScoutApm
  module Logging
    module Collector
      # Manager class for the downloading, configuring, and starting of the collector.
      class Manager
        attr_reader :context

        KNOWN_CHECKSUMS = {
          'linux_arm64' => 'e5a57598591a03f87b2a3cd4de6359da2c343e3b482b192f41fe9ed22d2e2e7b',
          'linux_amd64' => '583f5976578db7a8fe3079a7103bc0348020e06d698416b62661ddaa6bb57c9e',
          'darwin_arm64' => '60da15041b838998d1d652a4314ad8aacd24e4e313f1f0dc17692084ab2cea1b',
          'darwin_amd64' => 'c524fff8814cf02117d2ea047a5755ff07462ce2309864dd56f091a763c8712f'
        }.freeze

        def initialize(context)
          @context = context
        end

        def setup!
          Configuration.new(context).setup!
          Downloader.new(context).run!

          start_collector if verified_checksum?
        end

        def start_collector
          context.logger.info('Starting otelcol-contrib')
          collector_process = Process.spawn("#{extracted_collector_path}/otelcol-contrib --config #{config_file}")
          File.write(context.config.value('collector_pid_file'), collector_process)
        end

        private

        def verified_checksum?
          checksum = `sha256sum #{extracted_collector_path}/otelcol-contrib`.split(' ').first
          same_checksum_result = checksum == KNOWN_CHECKSUMS[double]

          log_failed_checksum unless same_checksum_result
          same_checksum_result
        end

        def log_failed_checksum
          if KNOWN_CHECKSUMS.key?(double)
            context.logger.error('Checksum verification failed for otelcol-contrib binary.')
          else
            context.logger.error("Checksum verification failed for otelcol-contrib binary. Unknown architecture: #{double}")
          end
        end

        def double
          "#{Utils.get_host_os}_#{Utils.get_architecture}"
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
