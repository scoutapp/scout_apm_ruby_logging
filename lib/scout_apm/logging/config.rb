# frozen_string_literal: true

module ScoutApm
  module Logging
    class Config < ScoutApm::Config
      KNOWN_CONFIG_OPTIONS = [
        'config_file',
        'log_level',
        'log_stderr',
        'log_stdout',
        'log_file_path',
        'log_class',
        'logging_ingest_key',
        'logging_monitor',
        'monitor_pid_file'
      ]

      SETTING_COERCIONS = {
        'monitor_logs' => BooleanCoercion.new,
      }

      def self.with_file(context, file_path=nil, config={})
        overlays = [
          ConfigEnvironment.new,
          ConfigFile.new(context, file_path, config),
          ConfigDefaults.new,
          ConfigNull.new,
        ]
        new(context, overlays)
      end

      class ConfigDefaults
        DEFAULTS = {
          'log_level' => 'info',
          'monitor_pid_file' => '/tmp/scout_apm_log_monitor.pid',
        }.freeze
  
        def value(key)
          DEFAULTS[key]
        end
  
        def has_key?(key)
          DEFAULTS.has_key?(key)
        end

         # Defaults are here, but not counted as user specified.
        def any_keys_found?
          false
        end

        def name
          "defaults"
        end
      end
    end
  end
end
