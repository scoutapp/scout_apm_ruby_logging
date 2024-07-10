# frozen_string_literal: true

require 'json'
require 'logger'

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
          attributes_to_log[:pid] = Process.pid
          attributes_to_log[:msg] = msg2str(msg)
          attributes_to_log['service.name'] = service_name

          "#{attributes_to_log.to_json}\n"
        end

        private

        def attributes_to_log
          @attributes_to_log ||= {}
        end

        def format_datetime(time)
          time.utc.strftime(DATETIME_FORMAT)
        end

        # We may need to clean this up a bit.
        def service_name
          $PROGRAM_NAME
        end
      end
    end
  end
end
