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
