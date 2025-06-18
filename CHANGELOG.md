## 2.1.0
* Add ability to capture log line with logs.
  * `logs_capture_log_line: true`
* Add ability to capture stack trace with logs.
  * `logs_capture_call_stack: true`
  * See [#98](https://github.com/scoutapp/scout_apm_ruby_logging/pull/98) for benchmarks.
* Add ability to disable warn message on method_missing.
  * `logs_method_missing_warning: false`
* Add ability to log stack trace on method_missing.
  * `logs_method_missing_call_stack: true`
* Add tests for ActionCable.

## 2.0.0
* Remove vendored opentelmetry SDK.
* Add support for Ruby 3.4.
* Breaking: Drop support for Ruby 2.6, 2.7, 3.0. 
  * Note: The 1.x release is still maintained.

## 1.1.0
* Bump vendored SDK version to 0.2.0.

## 1.0.3
* Add capturing of queue for background jobs.
* Fix entrypoint name capturing for namespaced controllers.

## 1.0.2
* Fix / Re-add logging of configuration values on startup.
* Remove raw_bytes from payload.

## 1.0.1
* Update google-protobuf dependency to resolve to any version less than 4.x.x.

## 1.0.0
* Vendor OpenTelemetry SDK and remove the use of the collector and monitor processes.

## 0.0.13
* Add ability to handle other libraries setting the Rails logger.
* Overwrite comparability methods on the proxy class. Have proxy class inherit from Object again.
* Clone original log instances.

## 0.0.12
* Prevent certain attributes from being changed on created FileLogger.
* Update proxy class to inherit from BasicObject to relay class comparison methods
to held loggers.
* Fix ERB evaluation in scout_apm.yml config file to allow for usage of Rails.env.

## 0.0.11
* Fix Scout layer capturing in log attributes for background jobs.

## 0.0.10
* Remove capitalization from action name in the formatter, to match that of the standard format.

## 0.0.9
* Add Scout Transaction ID to log attributes.

## 0.0.8
* Fix internal method names for proxy logger to prevent accidental overriding.
* Re-broadcast to console in development for the proxy logger.
* Fix tags not being removed when yielded contents throw an exception.
* Fix missing return statement, where tagged logging patches were being added to unintended loggers.

## 0.0.7
* Fix determined logger level comparison

## 0.0.6
* Ensure logger level is set back to the original.

## 0.0.5
* Remove `msg` attribute after it has been moved to the log body to prevent duplication.

## 0.0.4
* Fix memoizing of log attributes, which could lead to persistent attributes.

## 0.0.3
* **Feature**: Add support for TaggedLogging.
* Add ability to customize file logger size. Increase default size to 10MiB.
* Fix an issue with removing of the monitor process when Rails workers exited, which was only intended for when the main process exits.
* Fix an issue with the known monitored logs state being removed on port flushing.
