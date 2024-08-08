## 0.0.3
* **Feature**: Add support for TaggedLogging.
* Add ability to customize file logger size. Increase default size to 10MiB.
* Fix an issue with removing of the monitor process when Rails workers exited, which was only intended for when the main process exits.
* Fix an issue with the known monitored logs state being removed on port flushing.
