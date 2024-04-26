# frozen_string_literal: true

##
# Launched as a daemon process by the monitor manager and Rails startup.
##

module ScoutApm
  module Logging
    class Monitor
      def run
        loop do
          sleep 1
          puts "Running..."
        end
      end
    end
  end
end
