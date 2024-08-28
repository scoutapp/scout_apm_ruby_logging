# frozen_string_literal: true

# We start the monitor process outside the context of Rails, and ultimately don't use
# it for anything related to starting the collector. However, when we load the config/scout_apm.yml file,
# we support ERB, and users may be using Rails.env methods for naming the app, or configuring whether
# monitor should be enabled for a specific environment.

require 'active_support'

# https://github.com/rails/rails/blob/v7.2.1/railties/lib/rails.rb#L76
module Rails
  class << self
    def env
      # EnvironmentInquirer was added in Rails 6.1
      @env ||= if const_defined?('::ActiveSupport::EnvironmentInquirer')
                 ::ActiveSupport::EnvironmentInquirer.new(ENV['RAILS_ENV'].presence || ENV['RACK_ENV'].presence || 'development')
               else
                 ::ActiveSupport::StringInquirer.new(ENV['RAILS_ENV'].presence || ENV['RACK_ENV'].presence || 'development')
               end
    end
  end
end
