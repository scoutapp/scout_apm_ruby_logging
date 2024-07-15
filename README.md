# ScoutApm Ruby Logging

[![Build Status](https://github.com/scoutapp/scout_apm_ruby_logging/actions/workflows/test.yml/badge.svg)](https://github.com/scoutapp/scout_apm_ruby_logging/actions)

A Ruby gem for detailed, easy to navigate, managed log monitoring.

Sign up for an account at https://www.scoutapm.com to start monitoring your logs and application performance in minutes.

## Getting Started
Add the gem to your Gemfile: 

```ruby
gem 'scout_apm_logging'
```

Update your Gemfile: 
```ruby
bundle install
```

Update your [RAILS_ROOT/config/scout_apm.yml](https://scoutapm.com/apps/new_ruby_application_configuration) and add the following:

```yaml
  # ... Previous &defaults or environment defined configurations

  # ENV equivalent: SCOUT_LOGS_MONITOR=true
  # ENV equivalent: SCOUT_LOGS_INGEST_KEY=...

  logs_monitor: true
  logs_ingest_key: ...
```

Deploy :rocket:

## Testing
To run the entire test suite:
```ruby
bundle exec rake test
```

To run an individual test file within the suite:
```ruby
bundle exec rake test file=/path/to/spec/_spec.rb
```

To run test(s) against a specific Ruby version:
```ruby
DOCKER_RUBY_VERSION=3.3 bundle exec rake test
```

## Local
Point your Gemfile at your local checkout: 
```ruby
gem 'scout_apm_logging', path: '/path/to/scout_apm_ruby_logging'
```

## Help
Email support@scoutapm.com if you need a hand.
