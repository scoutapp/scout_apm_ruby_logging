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
        monitor_logs
        monitor_pid_file
        monitor_state_file
        collector_sending_queue_storage_dir
        collector_offset_storage_dir
        collector_pid_file
        collector_download_dir
        collector_config_file
        collector_version
        manager_lock_file
        monitored_logs
        logs_reporting_endpoint
        monitor_interval
        health_check_port
        delay_first_healthcheck
        logs_config
      ].freeze

      SETTING_COERCIONS = {
        'monitor_logs' => BooleanCoercion.new,
        'monitored_logs' => JsonCoercion.new,
        'monitor_interval' => IntegerCoercion.new,
        'delay_first_healthcheck' => IntegerCoercion.new,
        'health_check_port' => IntegerCoercion.new,
      }.freeze

      def self.with_file(context, file_path = nil, config = {})
        overlays = [
          ConfigEnvironment.new,
          ConfigFile.new(context, file_path, config),
          ConfigDynamic.new,
          ConfigDefaults.new,
          ConfigNull.new
        ]
        instance = new(context, overlays)

        # We need the current settings to determine where the state file is.
        instance.add_overlay(ConfigState.new(instance), index: 3)

        instance
      end

      def flush_state!
        State.flush_to_file!(self)
      end

      def add_overlay(overlay, index: -1)
        @overlays.insert(index, overlay)
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

      class ConfigDynamic
        @@values_to_set = {
          'health_check_port': nil,
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
          'dynamic'
        end
      end

      class ConfigState
        attr_reader :config

        def initialize(config)
          @config=config

          set_values_from_state
        end

        @@values_to_set = {
          'monitored_logs': [],
          'health_check_port': nil,
        }

        def self.set_value(key, value)
          @@values_to_set[key] = value
        end

        def self.get_values_to_set
          @@values_to_set.keys.map(&:to_s)
        end


        def value(key)
          @@values_to_set[key]
        end

        def has_key?(key)
          @@values_to_set.key?(key)
        end

        def name
          'state'
        end

        private

        def set_values_from_state
          data = State.load_state_from_file(config)

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
          'monitor_pid_file' => '/tmp/scout_apm/scout_apm_log_monitor.pid',
          'monitor_state_file' => '/tmp/scout_apm/scout_apm_log_monitor_state.json',
          'collector_offset_storage_dir' => '/tmp/scout_apm/file_storage/receiver/',
          'collector_sending_queue_storage_dir' => '/tmp/scout_apm/file_storage/otc/',
          'collector_pid_file' => '/tmp/scout_apm/scout_apm_otel_collector.pid',
          'collector_download_dir' => '/tmp/scout_apm/',
          'collector_config_file' => '/tmp/scout_apm/config.yml',
          'collector_version' => '0.102.1',
          'manager_lock_file' => '/tmp/scout_apm/monitor_lock_file.lock',
          'monitored_logs' => [],
          'logs_reporting_endpoint' => 'https://otlp.telemetryhub.com:4317',
          'monitor_interval' => 60,
          'delay_first_healthcheck' => 60
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
