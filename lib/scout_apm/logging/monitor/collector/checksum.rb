# frozen_string_literal: true

module ScoutApm
  module Logging
    module Collector
      # Contains logic around verifying the checksum of the otelcol-contrib binary.
      class Checksum
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

        def verified_checksum?(should_log_failures: false)
          return false unless File.exist?("#{extracted_collector_path}/otelcol-contrib")

          checksum = `sha256sum #{extracted_collector_path}/otelcol-contrib`.split(' ').first
          same_checksum_result = checksum == KNOWN_CHECKSUMS[double]

          log_failed_checksum if !same_checksum_result && should_log_failures
          same_checksum_result
        end

        def log_failed_checksum
          if KNOWN_CHECKSUMS.key?(double)
            context.logger.error('Checksum verification failed for otelcol-contrib binary.')
          else
            context.logger.error("Checksum verification failed for otelcol-contrib binary. Unknown architecture: #{double}")
          end
        end

        private

        def double
          "#{Utils.get_host_os}_#{Utils.get_architecture}"
        end

        def extracted_collector_path
          context.config.value('collector_download_dir')
        end
      end
    end
  end
end