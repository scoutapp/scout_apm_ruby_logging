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
# logs_capture_call_stack - true or false. If true, capture the call stack for each log message
# logs_capture_log_line - true or false. If true, capture the log line for each log message
# logs_call_stack_search_depth - the number of frames to search in the call stack
# logs_call_stack_capture_depth - the number of frames to capture in the call stack
# logs_method_missing_warning - true or false. If true, log a warning when method_missing is called
# logs_method_missing_call_stack -  true or false. If true, capture the call stack when method_missing is called
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
        logs_ingest_key
        logs_capture_level
        logs_config
        logs_reporting_endpoint
        logs_reporting_endpoint_http
        logs_proxy_log_dir
        logs_log_file_size
        logs_capture_call_stack
        logs_capture_log_line
        logs_call_stack_search_depth
        logs_call_stack_capture_depth
        logs_method_missing_warning
        logs_method_missing_call_stack
      ].freeze

      SETTING_COERCIONS = {
        'logs_monitor' => BooleanCoercion.new,
        'logs_capture_call_stack' => BooleanCoercion.new,
        'logs_capture_log_line' => BooleanCoercion.new,
        'logs_call_stack_search_depth' => IntegerCoercion.new,
        'logs_call_stack_capture_depth' => IntegerCoercion.new,
        'logs_log_file_size' => IntegerCoercion.new,
        'logs_method_missing_warning' => BooleanCoercion.new,
        'logs_method_missing_call_stack' => BooleanCoercion.new
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
          ConfigDefaults.new,
          ConfigNull.new
        ]
        new(context, overlays)
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

      # Defaults in case no config file has been found.
      class ConfigDefaults
        DEFAULTS = {
          'log_level' => 'info',
          'logs_capture_level' => 'debug',
          'logs_ingest_key' => '',
          'logs_reporting_endpoint' => 'https://otlp.scoutotel.com:4317',
          'logs_reporting_endpoint_http' => 'https://otlp.scoutotel.com:4318/v1/logs',
          'logs_proxy_log_dir' => '/tmp/scout_apm/logs/',
          'logs_log_file_size' => 1024 * 1024 * 10,
          'logs_capture_call_stack' => false,
          'logs_capture_log_line' => false,
          'logs_call_stack_search_depth' => 15,
          'logs_call_stack_capture_depth' => 2,
          'logs_method_missing_warning' => true,
          'logs_method_missing_call_stack' => false
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
