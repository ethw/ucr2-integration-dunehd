# Dune-HD integration for Remote Two / 3 Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

_Changes in the next release_

### Fixed
- Status polling could stop permanently, leaving the entity unavailable (and activities reporting the
  device as unreachable) until the integration was reconfigured, while commands kept working.
  `connect()` now replaces a finished polling task, a successful command revives polling,
  a polling task that dies is logged, and each poll has an explicit timeout.
- The command HTTP session is recreated after a failed command.
- Unsubscribing entities no longer raises `TypeError` (`disconnect()` was awaited but is synchronous).

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
