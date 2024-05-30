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
          'darwin_amd64' =>
           'cd2ee4b88edafd2d4264f9e28834683c60dab21a46493b7398b806b43c7bee3a',
          'darwin_arm64' =>
          '320e5a3c282759238248a9dbb0a39980865713e4335685e1990400436a57cffa',
          'linux_amd64' =>
          '58474c2ae87fbc41a8acf20bfd3a4b82f2b13a26f767090062e42a6a857bfb89',
          'linux_arm64' =>
          '4d5e2f9685ecc46854d09fa38192c038597392e2565be9edd162810e80bd42de'
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
          checksum = `sha256sum #{context.config.value('collector_download_dir')}/otelcol.tar.gz`.split(' ').first
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
