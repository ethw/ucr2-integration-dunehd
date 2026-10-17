# Dune-HD integration for Remote Two / 3 Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

_Changes in the next release_

### Added
- Simple command `CURSOR_ENTER_LONG`: long press OK on Android-based players (#5). IP Control can only
  emulate a short press, so this goes over ADB (port 5555): a persistent virtual HID remote on the player
  (`/dev/uhid`) holds Menu Pick for 0.45 s. About 0.5 s per press over a kept ADB connection. Map it to
  the OK button's long press in an activity. The ADB key is created in the configuration directory; a
  player with ADB authorisation on asks once to allow it.

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
