require 'fileutils'

module ScoutApm
  module Logging
    module Utils
      def self.ensure_directory_exists(file_path)
        directory = File.dirname(file_path)
        FileUtils.mkdir_p(directory) unless File.directory?(directory)
      end
    end
  end
end
