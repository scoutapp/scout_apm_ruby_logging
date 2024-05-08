# frozen_string_literal: true

module ScoutApm
  module Logging
    module Collector
      # Downloads the collector-contrib binary from the OpenTelemetry project.
      class Downloader
        attr_reader :context

        def initialize(context)
          @context = context
        end

        def run!
          download_collector
          extract_collector
        end

        def download_collector(url = nil) # rubocop:disable Metrics/AbcSize
          return if File.exist?(destination)

          context.logger.debug("Downloading otelcol-contrib for version #{context.config.value('collector_version')}")

          url_to_download = url || collector_url
          uri = URI(url_to_download)

          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
            request = Net::HTTP::Get.new(uri)
            http.request(request) do |response|
              return download_collector(response['location']) if response.code == '302'

              File.open(destination, 'wb') do |file|
                response.read_body do |chunk|
                  file.write(chunk)
                end
              end
            end
          end
        end

        def extract_collector
          Utils.ensure_directory_exists(destination)
          system("tar -xzf #{destination} -C #{context.config.value('collector_download_dir')}")
        end

        private

        def collector_url
          collector_version = context.config.value('collector_version')
          architecture = Utils.get_architecture
          host_os = Utils.get_host_os

          # https://opentelemetry.io/docs/collector/installation/#manual-linux-installation
          "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{collector_version}/otelcol-contrib_#{collector_version}_#{host_os}_#{architecture}.tar.gz"
        end

        def destination
          "#{context.config.value('collector_download_dir')}/otelcol.tar.gz"
        end
      end
    end
  end
end
