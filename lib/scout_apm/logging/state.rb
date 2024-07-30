# frozen_string_literal: true

module ScoutApm
  module Logging
    class Config
      # Responsibling for ensuring safe interprocess persitance around configuration state.
      class State
        attr_reader :context

        def initialize(context)
          @context = context
        end

        def load_state_from_file
          return unless File.exist?(context.config.value('monitor_state_file'))

          file_contents = File.read(context.config.value('monitor_state_file'))
          JSON.parse(file_contents)
        end

        def flush_to_file!(updated_log_locations = []) # rubocop:disable Metrics/AbcSize
          Utils.ensure_directory_exists(context.config.value('monitor_state_file'))

          File.open(context.config.value('monitor_state_file'), (File::RDWR | File::CREAT), 0o644) do |file|
            file.flock(File::LOCK_EX)

            data = Config::ConfigState.get_values_to_set.each_with_object({}) do |key, memo|
              memo[key] = context.config.value(key)
            end

            contents = file.read
            old_log_state_files = if contents.empty?
                                    []
                                  else
                                    current_data = JSON.parse(contents)
                                    current_data['logs_monitored']
                                  end

            data['logs_monitored'] =
              merge_and_dedup_log_locations(updated_log_locations, old_log_state_files, data['logs_monitored'])

            file.rewind # Move cursor to beginning of the file
            file.truncate(0) # Truncate existing content
            file.write(JSON.pretty_generate(data))
          rescue StandardError => e
            context.logger.error("Error occurred while flushing state to file: #{e.message}. Unlocking.")
          ensure
            file.flock(File::LOCK_UN)
          end
        end

        private

        # Should we add better detection for similar basenames but different paths?
        # May be a bit tricky with tools like capistrano and releases paths differentiated by time.
        def merge_and_dedup_log_locations(*log_locations)
          # Take the new logs if duplication (those first passed in the args) as we could be in a newer release.
          logs = log_locations.reduce([], :concat)
          merged = logs.each_with_object({}) do |log_path, hash|
            base_name = File.basename(log_path)
            hash[base_name] ||= log_path
          end

          merged.values
        end
      end
    end
  end
end
