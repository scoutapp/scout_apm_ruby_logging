# frozen_string_literal: true

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
        logging_ingest_key
        logging_monitor
        monitor_pid_file
        collector_download_dir
        collector_config_file
        collector_version
        monitored_logs
        logs_reporting_endpoint
        monitor_interval
      ].freeze

      SETTING_COERCIONS = {
        'monitor_logs' => BooleanCoercion.new,
        'monitored_logs' => JsonCoercion.new,
        'monitor_interval' => IntegerCoercion.new
      }.freeze

      def self.with_file(context, file_path = nil, config = {})
        overlays = [
          ConfigEnvironment.new,
          ConfigFile.new(context, file_path, config),
          ConfigDynamic.new,
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

      # We try and make assumptions about where the Rails log file is located.
      class ConfigDynamic
        @@values_to_set = {
          'monitored_logs': []
        }

        def self.set_value(key, value)
          @@values_to_set[key] = value
        end

        def value(key)
          @@values_to_set[key]
        end

        def has_key?(key)
          @@values_to_set.key?(key)
        end

        def name
          'defaults'
        end
      end

      # Defaults in case no config file has been found.
      class ConfigDefaults
        DEFAULTS = {
          'log_level' => 'info',
          'monitor_pid_file' => '/tmp/scout_apm/scout_apm_log_monitor.pid',
          'collector_download_dir' => '/tmp/scout_apm',
          'collector_config_file' => '/tmp/scout_apm/config.yml',
          'collector_version' => '0.100.0',
          'monitored_logs' => [],
          'logs_reporting_endpoint' => 'https://otlp.telemetryhub.com:4317',
          'monitor_interval' => 60
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
          'dynamic'
        end
      end
    end
  end
end