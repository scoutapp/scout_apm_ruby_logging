# frozen_string_literal: true

module ScoutApm
  module Logging
    # Contains context around Scout APM logging, such as environment, configuration, and the logger.
    class Context
      # Useful for the monitor daemon process, where we get the Rails root through the pipe.
      attr_accessor :environment_root
      attr_accessor :environment_type

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
        @config ||= ScoutApm::Logging::Config.without_file(self)
      end

      def environment
        @environment ||= ScoutApm::Environment.instance
      end

      def logger
        @logger ||= LoggerFactory.build(config, environment, environment_root)
      end

      def config=(config)
        @config = config

        @logger = nil

        # TODO
        # log_configuration_settings
      end
    end

    # Create a logger based on the configuration settings.
    class LoggerFactory
      def self.build(config, environment, environment_root = nil)
        root = environment_root || environment.root
        ScoutApm::Logging::Logger.new(root,
                                      {
                                        log_level: config.value('log_level'),
                                        log_file_path: config.value('log_file_path'),
                                        stdout: config.value('log_stdout') || environment.platform_integration.log_to_stdout?,
                                        stderr: config.value('log_stderr'),
                                        logger_class: config.value('log_class')
                                      })
      end

      def self.build_minimal_logger
        ScoutApm::Logging::Logger.new(nil, stdout: true)
      end
    end
  end
end
