# frozen_string_literal: true

module ScoutApm
  module Logging
    # Responsibling for ensuring safe interprocess persitance around configuration state.
    class Config::State
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def load_state_from_file
        return unless File.exist?(context.config.value('monitor_state_file'))

        file_contents = File.read(context.config.value('monitor_state_file'))
        data = JSON.parse(file_contents)
      end

      def flush_to_file!(new_log_files = [])
        Utils.ensure_directory_exists(context.config.value('monitor_state_file'))

        File.open(context.config.value('monitor_state_file'), (File::RDWR | File::CREAT), 0644) do |file|
          file.flock(File::LOCK_EX)

          data = Config::ConfigState.get_values_to_set.inject({}) do |memo, key|
            memo[key] = context.config.value(key)
            memo
          end

          unless new_log_files.empty?
            contents = file.read

            olds_log_files = unless contents.empty?
              current_data = JSON.parse(contents)
              current_data['monitored_logs']
            else
              []
            end

            data['monitored_logs'] = merge_and_dedup_log_locations(new_log_files, olds_log_files)
          end

          file.rewind # Move cursor to beginning of the file
          file.truncate(0) # Truncate existing content
          file.write(JSON.pretty_generate(data))
        end
      end

      private

      # Should we add better detection for similar basenames but different paths?
      # May be a bit tricky with tools like capistrano and releases paths differentiated by time.
      def merge_and_dedup_log_locations(new_logs, old_logs)
        # Take the new logs if duplication, as we could be in a newer release.
        merged = (new_logs + old_logs).each_with_object({}) do |log_path, hash|
          base_name = File.basename(log_path)
          hash[base_name] ||= log_path
        end

        merged.values
      end
    end
  end
end
