$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'scout_apm/logging/version'

Gem::Specification.new do |s|
  s.name        = 'scout_apm_logging'
  s.version     = ScoutApm::Logging::VERSION
  s.authors     = 'Scout APM'
  s.email       = ['support@scoutapp.com']
  s.homepage    = 'https://github.com/scoutapp/scout_apm_ruby_logging'
  s.summary     = 'Managed log monitoring for Ruby applications.'
  s.description = 'Sets up log monitoring for Scout APM Ruby clients.'
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 3.1'

  s.add_dependency 'googleapis-common-protos-types'
  s.add_dependency 'google-protobuf', '>= 3.18'
  s.add_dependency 'opentelemetry-api'
  s.add_dependency 'opentelemetry-common'
  s.add_dependency 'opentelemetry-exporter-otlp-logs', '>= 0.2.0'
  s.add_dependency 'opentelemetry-instrumentation-base'
  s.add_dependency 'opentelemetry-logs-sdk', '>= 0.2.0'
  s.add_dependency 'opentelemetry-sdk', '>= 1.2'
  s.add_dependency 'scout_apm'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rubocop', '1.50.2'
  s.add_development_dependency 'rubocop-ast', '1.30.0'
  s.add_development_dependency 'webmock'
  # Old, but works. It is a small wrapper library around websocket-eventmachine
  # for ActionCable protocols.
  s.add_development_dependency 'action_cable_client'
end
