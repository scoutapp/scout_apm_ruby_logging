# frozen_string_literal: true

module ScoutApm
  module Logging
    class Logger < ScoutApm::Logger

      private

      def determine_log_destination
        case true
        when stdout?
          STDOUT
        when stderr?
          STDERR
        when validate_path(@opts[:log_file])
          @opts[:log_file]
        when validate_path("#{log_file_path}/scout_apm_logging.log")
          "#{log_file_path}/scout_apm_logging.log"
        else
          # Safe fallback
          STDOUT
        end
      end
    end
  end
end
