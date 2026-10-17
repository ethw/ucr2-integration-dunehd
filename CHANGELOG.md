# Dune-HD integration for Remote Two / 3 Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

_Changes in the next release_

### Fixed
- Every command failed with an error ("Internal Server Error" on the remote) and status polling
  dropped while the Dune reported `playback_state` or `previous_playback_state` `buffering`, which
  happens after starting or seeking a network stream until the next state change. Unknown player and
  playback states now parse as `unknown`, `buffering` is known and maps to the buffering state, and
  `playback_speed` accepts any integer. Likely the cause of #4.

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
