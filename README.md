# Dune-HD integration for Remote Two / 3

> **This is a fork** of [petercv/ucr2-integration-dunehd](https://github.com/petercv/ucr2-integration-dunehd)
> with fixes and one feature that are not (yet) upstream. It runs on a Remote 3 in daily use.
> Issues are welcome and may be looked at, but **this fork comes with no guarantee of support**.
> For anything not listed below, the upstream project is the reference.

## What is different from upstream

Each change lives on its own branch off upstream `main`, so it can be reviewed or
submitted upstream on its own. `main` here combines all of them.

| Change | Branch | Why |
|---|---|---|
| **Buffering state no longer breaks the driver** | `fix/buffering-state` | The Dune reports `playback_state` / `previous_playback_state` `buffering` after starting or seeking a network stream. Upstream's enum lacks it, so every status reply failed validation: every button press returned an error ("Internal Server Error" on the remote) and the entity dropped until the next state change. Unknown states now parse as `unknown`. Probably the cause of upstream #4 (connection drops when scrubbing). |
| **Status polling recovers** | `fix/polling-recovery` | Polling could stop for good, leaving the entity unavailable until the integration was reconfigured. A finished polling task is replaced, a successful command revives polling, and each poll has a timeout. |
| **Reconnect state** | `fix/reconnect-state` | `on_device_update` was not awaited on (re)connect and the synchronous `disconnect()` was awaited, raising `TypeError` on unsubscribe. |
| **Fast-forward / rewind work** | `fix/fast-forward-rewind` | They were advertised to the remote, but the command handler had no branch for them, so they returned "not implemented". |
| **No crash on a status without `ui_state`** | `fix/ui-state-default` | `ui_state` defaulted to the tuple `(None,)` and the artwork code read it unguarded, raising `AttributeError` during playback without a picture. |
| **No credentials in the media title** | `fix/hide-url-query` | For a stream started by URL the Dune's caption is the URL, query string included, which can carry an API key; the query is dropped before it reaches the remote's screen. |
| **Log level INFO by default** | `fix/default-log-level` | Upstream defaults to DEBUG, logging every websocket message on the remote. `UC_LOG_LEVEL=DEBUG` still works. |
| **Long press OK** (new simple command `CURSOR_ENTER_LONG`) | `feature/adb-long-press` | Upstream #5. Android detects a long press by how long the key is held, and IP Control's `ir_code` only sends a complete short press, so this uses ADB (port 5555, ADB over network enabled on the player): a persistent virtual HID remote on the player holds OK for 0.45 s. About 0.5 s per press. Map it to the OK button's long press in an activity. The ADB key is created in the integration's configuration directory; a player with ADB authorisation on asks once to allow it. |

Versions here continue from upstream's (0.3.x) so the remote accepts them as updates
(`POST /api/intg/install?update=true`). Build steps are upstream's, see below; without an
arm64 machine or Docker binfmt, `tools/build-aarch64-proot.sh` builds the on-device archive
under proot + qemu-user.

---


Using [uc-integration-api](https://github.com/aitatoi/integration-python-library)

The driver lets you enter the IP address of a Dune-HD device and exposes a
[media player entity](https://github.com/unfoldedcircle/core-api/blob/main/doc/entities/entity_media_player.md)
to the Remote Two.

Supported attributes:
- State (on, standby, playing, paused, seeking, buffering, unknown)
- Title
- Artwork
- Media duration
- Media position

Supported commands:
- Turn on & off (device will be put into standby)
- Next / Previous
- Rewind / Fast-forward
- Volume up / down / Mute
- Channel up / down
- Play / pause
- Back
- Directional pad navigation and select
- Digits
- Context menu
- Top menu
- Subtitle
- Audio track

## Usage
### Setup

- Requires Python 3.11
- Install required libraries:  
  (using a [virtual environment](https://docs.python.org/3/library/venv.html) is highly recommended)
```shell
pip3 install -r requirements.txt
```

### Run

```shell
python3 src/driver.py
```

See available [environment variables](https://github.com/unfoldedcircle/integration-python-library#environment-variables)
in the Python integration library to control certain runtime features like listening interface and configuration directory.

The configuration file is loaded & saved from the path specified in the environment variable `UC_CONFIG_HOME`.
Otherwise, the `HOME` path is used or the working directory as fallback.

## Build Docker image

Simply run:
```shell
docker build .
```

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the
[tags and releases in this repository](https://github.com/petercv/ucr2-integration-dunehd/releases).

## Changelog

The major changes found in each new release are listed in the [changelog](CHANGELOG.md)
and under the GitHub [releases](https://github.com/petercv/ucr2-integration-dunehd/releases).

## License

This project is licensed under the [**Mozilla Public License 2.0**](https://choosealicense.com/licenses/mpl-2.0/).
See the [LICENSE](LICENSE) file for details.
