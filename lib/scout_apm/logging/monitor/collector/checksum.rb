# frozen_string_literal: true

module ScoutApm
  module Logging
    module Collector
      # Contains logic around verifying the checksum of the otelcol-contrib binary.
      class Checksum
        attr_reader :context

        KNOWN_CHECKSUMS = {
          'darwin_amd64' => '5456734e124221e7ff775c52bd3693d05b3fac43ebe06b22aa5f220f1962ed8c',
          'darwin_arm64' => 'f9564560798ac5c099885903f303fcda97b7ea649ec299e075b72f3805873879',
          'linux_amd64' => '326772622016f7ff7e966a7ae8a0f439dc49a3d80b6d79a82b62608af447e851',
          'linux_arm64' => '73d797817540363a37f27e32270f98053ed17b1df36df2d30db1715ce40f4cff'
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
