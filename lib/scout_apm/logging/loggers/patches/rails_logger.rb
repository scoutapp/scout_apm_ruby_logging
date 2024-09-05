# frozen_string_literal: true

# A patch to Rails to allow swapping out the logger for the held logger in the proxy.
module Rails
  class << self
    def logger=(new_logger)
      @logger.tap do |rails_logger|
        if rails_logger.respond_to?(:is_scout_proxy_logger?)
          old_logger = rails_logger.instance_variable_get(:@loggers).first
          rails_logger.swap_scout_loggers!(old_logger, new_logger)
        else
          @logger = new_logger
        end
      end
    end
  end
end
