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

      def self.check_process_liveliness(pid, name)
        # Pipe to cat to prevent truncation of the output
        process_information = `ps -p #{pid} -o pid=,stat=,command= | cat`
        return false if process_information.empty?

        process_information_parts = process_information.split(' ')
        process_information_status = process_information_parts[1]

        return false if process_information_status == 'Z'
        return false unless process_information.include?(name)

        true
      end

      def self.current_process_is_app_server?
        # TODO: Add more app servers.
        process_command = `ps -p #{Process.pid} -o command= | cat`.downcase
        [
          process_command.include?('puma'),
          process_command.include?('unicorn'),
          process_command.include?('passenger')
        ].any?
      end

      def self.skip_setup?
        [
          ARGV.include?('assets:precompile'),
          ARGV.include?('assets:clean'),
          (defined?(::Rails::Console) && $stdout.isatty && $stdin.isatty)
        ].any?
      end

      def self.attempt_exclusive_lock(context)
        lock_file = context.config.value('manager_lock_file')
        ensure_directory_exists(lock_file)

        begin
          file = File.open(lock_file, File::RDWR | File::CREAT | File::EXCL)
        rescue Errno::EEXIST
          context.logger.info('Manager lock file held, continuing.')
          return
        end

        # Ensure the lock file is deleted when the block completes
        begin
          yield
        ensure
          file.close
          File.delete(lock_file) if File.exist?(lock_file)
        end
      end
    end
  end
end
