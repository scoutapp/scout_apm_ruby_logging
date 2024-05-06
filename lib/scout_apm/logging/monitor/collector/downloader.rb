# frozen_string_literal: true

require 'open-uri'

module ScoutApm
  module Logging
    module Collector
      class Downloader
        attr_reader :context

        def initialize(context)
          @context = context
        end

        def run!
          download_collector
          extract_collector
        end

        def download_collector
          # TODO: Check if we have already downloaded the collector.
          File.open(destination, 'wb', 0777) do |file|
            open(collector_url, 'rb') do |downloaded_file|
              file.write(downloaded_file.read)
            end
          end
        end

        def extract_collector
          # ScoutApm::Logging::Utils.ensure_directory_exists(download_path)
          `tar -xzf #{destination} -C #{context.config.value('collector_download_dir')}`
        end

        private

        def collector_url
          collector_version = context.config.value('collector_version')
          
          # https://opentelemetry.io/docs/collector/installation/#manual-linux-installation
          "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{collector_version}/otelcol-contrib_#{collector_version}_#{host_os}_#{architecture}.tar.gz"
        end


        # TODO: Add support for other platforms
        def architecture
          if /arm/ =~ RbConfig::CONFIG['arch']
            'arm64'
          else
            'amd64'
          end
        end

        def host_os
          if /darwin|mac os/ =~ RbConfig::CONFIG['host_os']
            'darwin'
          else
            'linux'
          end
        end

        def destination
          context.config.value('collector_download_dir') + "/otelcol.tar.gz"
        end
      end
    end
  end
end
