require_relative '../proxy'

module Rails
  module Rack
    class Logger < ActiveSupport::LogSubscriber
      private

      def logger
        if Rails.logger.is_a?(ScoutApm::Logging::Loggers::Proxy)
          # With the use of logger.tagged(*compute_tags(request)) { call_app(request, env) }, we
          # will circle the request multiple times with the proxy logger. This appears to change
          # in 7.2 (which doesn't matter as much with the broadcast logger).
          Rails.logger.instance_variable_get(:@loggers).first
        else
          Rails.logger
        end
      end
    end
  end
end
