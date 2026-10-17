# Dune-HD integration for Remote Two / 3 Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

_Changes in the next release_

---

## v0.3.1 (fork) - 2026-10-17
### Fixed
- Fast-forward and rewind were advertised but returned "not implemented".
- A status without `ui_state` during playback raised `AttributeError` (tuple default) and dropped the connection.
- The media title no longer shows a stream URL's query string, which can hold credentials.
- Default log level is INFO (was DEBUG); `UC_LOG_LEVEL=DEBUG` still works.

## v0.3.0 (fork) - 2026-10-17
### Added
- Simple command `CURSOR_ENTER_LONG`: long press OK on Android-based players. IP Control can only
  emulate a short press, so this goes over ADB (port 5555): a persistent virtual HID remote on the player
  (`/dev/uhid`) holds Menu Pick for 0.45 s. About 0.5 s per press over a kept ADB connection. Map it to
  the OK button's long press in an activity. The ADB key is created in the configuration directory; a
  player with ADB authorisation on asks once to allow it.

## v0.2.5 (fork) - 2026-10-17
### Fixed
- Every command failed with an error ("Internal Server Error" on the remote) and status polling
  dropped while the Dune reported `playback_state` or `previous_playback_state` `buffering`, which
  happens after starting or seeking a network stream until the next state change. Unknown player and
  playback states now parse as `unknown`, `buffering` is known and maps to the buffering state, and
  `playback_speed` accepts any integer.

## v0.2.3 / v0.2.4 (fork) - 2026-10-01
### Fixed
- Status polling could stop permanently, leaving the entity unavailable (and activities reporting the
  device as unreachable) until the integration was reconfigured, while commands kept working.
  `connect()` now replaces a finished polling task, a successful command revives polling,
  a polling task that dies is logged, and each poll has an explicit timeout.
- The command HTTP session is recreated after a failed command.
- Unsubscribing entities no longer raises `TypeError` (`disconnect()` was awaited but is synchronous).
- `on_device_update` is awaited when a device (re)connects.

---

## v0.2.2 - 2025-12-20
### Changed
- Fixed color button mapping

## v0.2.1 - 2025-11-29
### Added
- Support color buttons

## v0.2.0 - 2025-11-25
### Added
- Support for on-device installation.

## v0.1.0 - 2024-03-31
### Added
- First version.
