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
      ].freeze

      SETTING_COERCIONS = {
        'monitor_logs' => BooleanCoercion.new,
        'monitored_logs' => JsonCoercion.new,
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

      # We try and make assumptioms about where the Rails log file is located.
      class ConfigDynamic
        VALUES_TO_SET = {
          'monitored_logs': [],
        }

        def self.set_value(key, value)
          VALUES_TO_SET[key] = value
        end

        def value(key)
          VALUES_TO_SET[key]
        end

        def has_key?(key)
          VALUES_TO_SET.key?(key)
        end
      end

      # Defaults in case no config file has been found.
      class ConfigDefaults
        DEFAULTS = {
          'log_level' => 'info',
          'monitor_pid_file' => '/tmp/scout_apm/scout_apm_log_monitor.pid',
          'collector_download_dir' => '/tmp/scout_apm',
          'collector_config_file' => '/tmp/scout_apm/config.yml',
          'collector_version' => '0.99.0',
          'monitored_logs' => [],
          'logs_reporting_endpoint' =>'https://otlp.telemetryhub.com:4317',
        }.freeze

        def value(key)
          DEFAULTS[key]
        end

        def has_key?(key)
          DEFAULTS.key?(key)
        end

        # Defaults are here, but not counted as user specified.
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
