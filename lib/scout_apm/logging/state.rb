# frozen_string_literal: true

module ScoutApm
  module Logging
    # Responsibling for ensuring safe interprocess persitance around configuration state.
    class Config::State # rubocop:disable Style/ClassAndModuleChildren
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def load_state_from_file
        return unless File.exist?(context.config.value('monitor_state_file'))

        file_contents = File.read(context.config.value('monitor_state_file'))
        JSON.parse(file_contents)
      end

      def flush_to_file! # rubocop:disable Metrics/AbcSize
        Utils.ensure_directory_exists(context.config.value('monitor_state_file'))

        File.open(context.config.value('monitor_state_file'), (File::RDWR | File::CREAT), 0o644) do |file|
          file.flock(File::LOCK_EX)

          # TODO: We will need to merge monitored_logs based on the data in the state file, and not
          # what is currently in the config.
          data = Config::ConfigState.get_values_to_set.each_with_object({}) do |key, memo|
            memo[key] = context.config.value(key)
          end

          file.rewind # Move cursor to beginning of the file
          file.truncate(0) # Truncate existing content
          file.write(JSON.pretty_generate(data))
          file.flock(File::LOCK_UN)
        end
      end
    end
  end
end
