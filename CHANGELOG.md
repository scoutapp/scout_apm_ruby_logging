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
