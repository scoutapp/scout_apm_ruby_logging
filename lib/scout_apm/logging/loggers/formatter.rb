# frozen_string_literal: true

require 'json'
require 'logger'

require 'scout_apm'

module ScoutApm
  module Logging
    module Loggers
      # A simple JSON formatter which we can add a couple attributes to.
      class Formatter < ::Logger::Formatter
        DATETIME_FORMAT = '%Y-%m-%dT%H:%M:%S.%LZ'

        def call(severity, time, progname, msg) # rubocop:disable Metrics/AbcSize
          attributes_to_log[:severity] = severity
          attributes_to_log[:time] = format_datetime(time)
          attributes_to_log[:progname] = progname if progname
          attributes_to_log[:pid] = Process.pid.to_s
          attributes_to_log[:msg] = msg2str(msg)
          attributes_to_log['service.name'] = service_name

          attributes_to_log.merge!(scout_layer)
          attributes_to_log.merge!(scout_context)
          # Naive local benchmarks show this takes around 200 microseconds. As such, we only apply it to WARN and above.
          attributes_to_log.merge!(local_log_location) if ::Logger::Severity.const_get(severity) >= ::Logger::Severity::WARN

          "#{attributes_to_log.to_json}\n"
        end

        private

        def attributes_to_log
          @attributes_to_log ||= {}
        end

        def format_datetime(time)
          time.utc.strftime(DATETIME_FORMAT)
        end

        def scout_layer
          req = ScoutApm::RequestManager.lookup
          layer = req.instance_variable_get('@layers').find { |lay| lay.type == 'Controller' || lay.type == 'Job' }

          return {} unless layer

          name, action = layer.name.split('/')

          derived_key = "#{layer.type.downcase}_entrypoint".to_sym
          derived_value_of_scout_name = "#{name.capitalize}#{layer.type.capitalize}##{action.capitalize}"

          { derived_key => derived_value_of_scout_name }
        end

        def scout_context
          req = ScoutApm::RequestManager.lookup
          extra_context = req.context.instance_variable_get('@extra')
          user_context = req.context.instance_variable_get('@user')
          # We may want to make this a configuration option in the future, as well as capturing
          # the URI from the request annotations, but this may include PII.
          user_context.delete(:ip)

          user_context.transform_keys { |key| "user.#{key}" }.merge(extra_context)
        end

        def local_log_location
          # Should give us the last local stack which called the log within just the last couple frames.
          last_local_location = caller[0..15].find { |path| path.include?(Rails.root.to_s) }

          return {} unless last_local_location

          { 'log_location' => last_local_location }
        end

        # We may need to clean this up a bit.
        def service_name
          $PROGRAM_NAME
        end
      end
    end
  end
end
