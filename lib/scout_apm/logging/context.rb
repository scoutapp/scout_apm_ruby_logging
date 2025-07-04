# frozen_string_literal: true

module ScoutApm
  module Logging
    # Contains context around Scout APM logging, such as environment, configuration, and the logger.
    class Context
      # The root of the application.
      attr_accessor :application_root

      # Use this as the entrypoint.
      def self.instance
        @@instance ||= new.tap do |instance|
          instance.config = ScoutApm::Logging::Config.with_file(instance, instance.config.value('config_file'))
          instance.config.log_settings(instance.logger)
        end
      end

      # Initially start up without attempting to load a configuration file. We
      # need to be able to lookup configuration options like "application_root"
      # which would then in turn influence where the yaml configuration file is
      # located
      #
      # Later in initialization, we set config= to include the file.
      def initialize
        @logger = LoggerFactory.build_minimal_logger
      end

      def config
        @config ||= Config.without_file(self)
      end

      def environment
        @environment ||= ScoutApm::Environment.instance
      end

      def logger
        @logger ||= LoggerFactory.build(config, environment, application_root)
      end

      def config=(config)
        @config = config

        @logger = nil
      end
    end

    # Create a logger based on the configuration settings.
    class LoggerFactory
      def self.build(config, environment, application_root = nil)
        root = application_root || environment.root
        Logger.new(root,
                   {
                     log_level: config.value('log_level'),
                     log_file_path: config.value('log_file_path'),
                     stdout: config.value('log_stdout') || environment.platform_integration.log_to_stdout?,
                     stderr: config.value('log_stderr'),
                     logger_class: config.value('log_class')
                   })
      end

      def self.build_minimal_logger
        Logger.new(nil, stdout: true)
      end
    end
  end
end
