# frozen_string_literal: true

require 'scout_apm'

module ScoutApm
  module Logging
    # Temporary class for testing hierarchy.
    class Hello
      def self.world
        puts 'Hello World.'
      end
    end
  end
end
