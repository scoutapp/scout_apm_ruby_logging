# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'scout_apm/logging/version'

Gem::Specification.new do |s|
  s.name        = 'scout_apm_logging'
  s.version     = ScoutApm::Logging::VERSION
  s.authors     = 'Scout APM'
  s.email       = ['support@scoutapp.com']
  s.homepage    = 'https://github.com/scoutapp/scout_apm_ruby_logging'
  s.summary     = 'Ruby Logging Support'
  s.description = 'Sets up log monitoring for Scout APM Ruby clients.'
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 2.6'

  s.add_dependency 'scout_apm'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rubocop', '1.50.2'
  s.add_development_dependency 'rubocop-ast', '.30.0'
end
