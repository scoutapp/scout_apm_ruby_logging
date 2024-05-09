# frozen_string_literal: true

require 'fileutils'

module ScoutApm
  module Logging
    # Miscellaneous utilities for the logging module.
    module Utils
      # Takes a complete file path, and ensures that the directory structure exists.
      def self.ensure_directory_exists(file_path)
        directory = File.dirname(file_path)
        FileUtils.mkdir_p(directory) unless File.directory?(directory)
      end

      # TODO: Add support for other platforms
      def self.get_architecture
        if /arm/ =~ RbConfig::CONFIG['arch']
          'arm64'
        else
          'amd64'
        end
      end

      def self.get_host_os
        if /darwin|mac os/ =~ RbConfig::CONFIG['host_os']
          'darwin'
        else
          'linux'
        end
      end
    end
  end
end
