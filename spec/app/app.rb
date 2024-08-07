require 'action_controller/railtie'
require 'logger'
require 'scout_apm_logging'

Rails.logger = Logger.new($stdout)

class App < ::Rails::Application
  config.eager_load = false

  routes.append do
    root to: 'root#index'
  end
end

class RootController < ActionController::Base
  def index
    render plain: Rails.version
  end
end

def initialize_app
  App.initialize!

  Rack::Server.start(app: App)
end
