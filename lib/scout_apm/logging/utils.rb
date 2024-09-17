# frozen_string_literal: true

require 'fileutils'

module ScoutApm
  module Logging
    # Miscellaneous utilities for the logging module.
    module Utils
      # Takes a complete file path, and ensures that the directory structure exists.
      def self.ensure_directory_exists(file_path)
        file_path = File.dirname(file_path) unless file_path[-1] == '/'

        FileUtils.mkdir_p(file_path) unless File.directory?(file_path)
      end
    end
  end
end
