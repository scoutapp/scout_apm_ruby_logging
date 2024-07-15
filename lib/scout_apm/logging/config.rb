# frozen_string_literal: true

# Valid Config Options:
#
# This list is complete, but some are for developers of
# scout_apm_logging itself. See the documentation at https://scoutapm.com/docs for
# customer-focused documentation.
#
# config_file - location of the scout_apm.yml configuration file
# log_level          - log level for the internal library itself
# log_stdout         - true or false.  If true, log to STDOUT
# log_stderr         - true or false.  If true, log to STDERR
# log_file_path      - either a directory or "STDOUT"
# log_class          - the underlying class to use for logging.  Defaults to Ruby's Logger class
# logs_monitor       - true or false.  If true, monitor logs
# logs_monitored     - an array of log file paths to monitor. Overrides the default log destination detection
# logs_ingest_key    - the ingest key to use for logs
# logs_capture_level - the minimum log level to start capturing logs for
# logs_config        - a hash of configuration options for merging into the collector's config
# logs_reporting_endpoint - the endpoint to send logs to
# logs_proxy_log_dir - the directory to store logs in for monitoring
# manager_lock_file  - the location for obtaining an exclusive lock for running monitor manager
# monitor_pid_file   - the location of the pid file for the monitor
# monitor_state_file - the location of the state file for the monitor
# monitor_interval   - the interval to check the collector healtcheck and for new state logs
# monitor_interval_delay - the delay to wait before running the first monitor interval
# collector_sending_queue_storage_dir - the directory to store queue files
# collector_offset_storage_dir - the directory to store offset files
# collector_pid_file - the location of the pid file for the collector
# collector_download_dir - the directory to store downloaded collector files
# collector_config_file - the location of the config file for the collector
# collector_version - the version of the collector to download
# health_check_port - the port to use for the collector health check. Default is dynamically derived based on port availability
#
# Any of these config settings can be set with an environment variable prefixed
# by SCOUT_ and uppercasing the key: SCOUT_LOG_LEVEL for instance.

module ScoutApm
  module Logging
    # Holds the configuration values for Scout APM Logging.
    class Config < ScoutApm::Config
      KNOWN_CONFIG_OPTIONS = %w[
        config_file
        log_level
        log_stderr
        log_stdout
        log_file_path
        log_class
        logs_monitor
        logs_monitored
        logs_ingest_key
        logs_capture_level
        logs_config
        logs_reporting_endpoint
        logs_proxy_log_dir
        manager_lock_file
        monitor_pid_file
        monitor_state_file
        monitor_interval
        monitor_interval_delay
        collector_sending_queue_storage_dir
        collector_offset_storage_dir
        collector_pid_file
        collector_download_dir
        collector_config_file
        collector_version
        health_check_port
      ].freeze

      SETTING_COERCIONS = {
        'logs_monitor' => BooleanCoercion.new,
        'logs_monitored' => JsonCoercion.new,
        'monitor_interval' => IntegerCoercion.new,
        'monitor_interval_delay' => IntegerCoercion.new,
        'health_check_port' => IntegerCoercion.new
      }.freeze

      # The bootstrapped, and initial config that we attach to the context. Will be swapped out by
      # both the monitor and manager on initialization to the one with a file (which also has the dynamic
      # and state configs).
      def self.without_file(context)
        overlays = [
          ConfigEnvironment.new,
          ConfigDefaults.new,
          ConfigNull.new
        ]
        new(context, overlays)
      end

      def self.with_file(context, file_path = nil, config = {})
        overlays = [
          ConfigEnvironment.new,
          ConfigFile.new(context, file_path, config),
          ConfigDynamic.new,
          ConfigState.new(context),
          ConfigDefaults.new,
          ConfigNull.new
        ]
        new(context, overlays)
      end

      def state
        @overlays.find { |overlay| overlay.is_a? ConfigState }
      end

      def value(key)
        unless KNOWN_CONFIG_OPTIONS.include?(key)
          logger.debug("Requested looking up a unknown configuration key: #{key} (not a problem. Evaluate and add to config.rb)")
        end

        o = overlay_for_key(key)
        raw_value = if o
                      o.value(key)
                    else
                      # No overlay said it could handle this key, bail out with nil.
                      nil
                    end

        coercion = SETTING_COERCIONS.fetch(key, NullCoercion.new)
        coercion.coerce(raw_value)
      end

      def all_settings
        KNOWN_CONFIG_OPTIONS.inject([]) do |memo, key|
          o = overlay_for_key(key)
          memo << { key: key, value: value(key).inspect, source: o.name }
        end
      end

      # Dynamically set state based on the application.
      class ConfigDynamic
        @values_to_set = {
          'health_check_port': nil
        }

        class << self
          attr_reader :values_to_set

          def set_value(key, value)
            @values_to_set[key] = value
          end
        end

        def value(key)
          self.class.values_to_set[key]
        end

        def has_key?(key)
          self.class.values_to_set.key?(key)
        end

        def name
          'dynamic'
        end
      end

      # State that is persisted and communicated upon by multiple processes.
      class ConfigState
        @values_to_set = {
          'logs_monitored': [],
          'health_check_port': nil
        }

        class << self
          attr_reader :values_to_set

          def set_value(key, value)
            @values_to_set[key] = value
          end

          def get_values_to_set
            @values_to_set.keys.map(&:to_s)
          end
        end

        attr_reader :context, :state

        def initialize(context)
          @context = context

          # Note, the config on the context we are passing in here comes from the Config.without_file. We
          # won't be aware of a state file that was defined in a config file, but this would be a very
          # rare thing to have happen as this is more of an internal config value.
          @state = State.new(context)

          set_values_from_state
        end

        def value(key)
          self.class.values_to_set[key]
        end

        def has_key?(key)
          self.class.values_to_set.key?(key)
        end

        def name
          'state'
        end

        def flush_state!
          state.flush_to_file!
        end

        def add_log_locations!(updated_log_locations)
          state.flush_to_file!(updated_log_locations)
        end

        private

        def set_values_from_state
          data = state.load_state_from_file

          return unless data

          data.each do |key, value|
            self.class.set_value(key, value)
          end
        end
      end

      # Defaults in case no config file has been found.
      class ConfigDefaults
        DEFAULTS = {
          'log_level' => 'info',
          'logs_monitored' => [],
          'logs_capture_level' => 'debug',
          'logs_reporting_endpoint' => 'https://otlp.telemetryhub.com:4317',
          'logs_proxy_log_dir' => '/tmp/scout_apm/logs/',
          'manager_lock_file' => '/tmp/scout_apm/monitor_lock_file.lock',
          'monitor_pid_file' => '/tmp/scout_apm/scout_apm_log_monitor.pid',
          'monitor_state_file' => '/tmp/scout_apm/scout_apm_log_monitor_state.json',
          'monitor_interval' => 60,
          'monitor_interval_delay' => 60,
          'collector_offset_storage_dir' => '/tmp/scout_apm/file_storage/receiver/',
          'collector_sending_queue_storage_dir' => '/tmp/scout_apm/file_storage/otc/',
          'collector_pid_file' => '/tmp/scout_apm/scout_apm_otel_collector.pid',
          'collector_download_dir' => '/tmp/scout_apm/',
          'collector_config_file' => '/tmp/scout_apm/config.yml',
          'collector_version' => '0.102.1'
        }.freeze

        def value(key)
          DEFAULTS[key]
        end

        def has_key?(key)
          DEFAULTS.key?(key)
        end

        # Dyanmic/computed values are here, but not counted as user specified.
        def any_keys_found?
          false
        end

        def name
          'defaults'
        end
      end
    end
  end
end
