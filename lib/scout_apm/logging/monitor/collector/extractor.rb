# frozen_string_literal: true

module ScoutApm
  module Logging
    module Collector
      # Extracts the contents of the collector tar file.
      class Extractor
        attr_reader :context

        def initialize(context)
          @context = context
        end

        def extract!
          # Already extracted. Noop.
          return if has_been_extracted?

          system("tar -xzf #{tar_path} -C #{context.config.value('collector_download_dir')}")
        end

        def has_been_extracted?
          File.exist?(binary_path)
        end

        private

        def tar_path
          "#{context.config.value('collector_download_dir')}/otelcol.tar.gz"
        end

        def binary_path
          "#{context.config.value('collector_download_dir')}/otelcol-contrib"
        end
      end
    end
  end
end
