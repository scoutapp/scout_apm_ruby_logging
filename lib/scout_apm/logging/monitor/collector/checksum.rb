# frozen_string_literal: true

module ScoutApm
  module Logging
    module Collector
      # Contains logic around verifying the checksum of the otelcol-contrib binary.
      class Checksum
        attr_reader :context

        KNOWN_CHECKSUMS = {
          'darwin_amd64' => 'cd2ee4b88edafd2d4264f9e28834683c60dab21a46493b7398b806b43c7bee3a',
          'darwin_arm64' => '320e5a3c282759238248a9dbb0a39980865713e4335685e1990400436a57cffa',
          'linux_amd64' => '58474c2ae87fbc41a8acf20bfd3a4b82f2b13a26f767090062e42a6a857bfb89',
          'linux_arm64' => '4d5e2f9685ecc46854d09fa38192c038597392e2565be9edd162810e80bd42de'
        }.freeze

        def initialize(context)
          @context = context
        end

        def verified_checksum?(should_log_failures: false)
          return false unless File.exist?(collector_tar_path)

          checksum = `sha256sum #{collector_tar_path}`.split(' ').first
          same_checksum_result = checksum == KNOWN_CHECKSUMS[double]

          log_failed_checksum if !same_checksum_result && should_log_failures
          same_checksum_result
        end

        def log_failed_checksum
          if KNOWN_CHECKSUMS.key?(double)
            context.logger.error('Checksum verification failed for otelcol.tar.gz.')
          else
            context.logger.error("Checksum verification failed for otelcol.tar.gz. Unknown architecture: #{double}")
          end
        end

        private

        def double
          "#{Utils.get_host_os}_#{Utils.get_architecture}"
        end

        def collector_tar_path
          "#{context.config.value('collector_download_dir')}/otelcol.tar.gz"
        end
      end
    end
  end
end
