"""
Long-press OK on Android-based Dune-HD players over ADB.

The Dune IP Control protocol can only emulate a short key press (``ir_code`` sends press and
release together), so a long press -- which Android detects by how long a key is held -- is not
possible over IP Control. This module holds a virtual HID remote open on the player through
``/dev/uhid`` and presses its Menu Pick key (KEY_SELECT, Android DPAD_CENTER) for a moment
longer than Android's long-press timeout.

The virtual device is created once by a small process on the player that keeps ``/dev/uhid``
open and copies key reports from a FIFO, so a long press is one ADB shell call: key down,
wait, key up. The ADB connection is kept open between presses.

The first connection needs the "Allow USB debugging?" prompt on the player to be accepted
(tick "Always allow"); the ADB key lives in the integration's configuration directory.

:license: Mozilla Public License Version 2.0, see LICENSE for more details.
"""

import asyncio
import logging
import os

from adb_shell.adb_device_async import AdbDeviceTcpAsync
from adb_shell.auth.keygen import keygen
from adb_shell.auth.sign_pythonrsa import PythonRSASigner

_LOG = logging.getLogger(__name__)

ADB_PORT = 5555
# Android's default long_press_timeout is 400 ms; hold a little longer.
HOLD_SECONDS = 0.45

# UHID_CREATE2 for a Bluetooth consumer-control device "UC Long Select" (vid 0x1234, pid 0x5678)
# whose only usage is Menu Pick (0x41).
_UHID_CREATE2_B64 = (
    "CwAAAFVDIExvbmcgU2VsZWN0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAXAAUANBIAAHhWAAAAAAAAAAAAAAUMCQGhARUAJv8DGQAq/wN1EJUB"
    "gQDA"
)
# UHID_INPUT2 reports: Menu Pick down / all keys up.
_KEY_DOWN = r"\014\000\000\000\002\000\101\000"
_KEY_UP = r"\014\000\000\000\002\000\000\000"

_DIR = "/data/local/tmp"
_FIFO = f"{_DIR}/uc_lp.fifo"
_PID = f"{_DIR}/uc_lp.pid"
_CREATE = f"{_DIR}/uc_lp_create.bin"

# Starts the holder process unless it is already running, then presses and releases the key.
_LONG_PRESS_SCRIPT = (
    f'if ! {{ [ -f {_PID} ] && kill -0 "$(cat {_PID})" 2>/dev/null; }}; then '
    f"echo {_UHID_CREATE2_B64} | base64 -d > {_CREATE}; rm -f {_FIFO}; mkfifo {_FIFO}; "
    f'nohup sh -c "echo \\$\\$ > {_PID}; exec 3<>{_FIFO}; {{ cat {_CREATE}; exec cat <&3; }} > /dev/uhid" '
    f">/dev/null 2>&1 & sleep 0.3; fi; "
    f"printf '{_KEY_DOWN}' > {_FIFO}; sleep {HOLD_SECONDS}; printf '{_KEY_UP}' > {_FIFO}; echo ok"
)


class AdbLongPress:
    """Sends long presses of OK to a Dune-HD player over a persistent ADB connection."""

    def __init__(self, address: str, key_dir: str) -> None:
        """Create instance for the player at ``address``; the ADB key is kept in ``key_dir``."""
        self._address = address
        self._key_path = os.path.join(key_dir, "adbkey")
        self._device: AdbDeviceTcpAsync | None = None
        self._lock = asyncio.Lock()

    def _signer(self) -> PythonRSASigner:
        if not os.path.exists(self._key_path):
            _LOG.info("Generating ADB key %s", self._key_path)
            keygen(self._key_path)
        return PythonRSASigner.FromRSAKeyPath(self._key_path)

    async def _connected_device(self) -> AdbDeviceTcpAsync:
        if self._device is not None and self._device.available:
            return self._device
        device = AdbDeviceTcpAsync(self._address, ADB_PORT, default_transport_timeout_s=5)
        signer = await asyncio.get_running_loop().run_in_executor(None, self._signer)
        # Allow time for the "Allow USB debugging?" prompt on first use.
        await device.connect(rsa_keys=[signer], auth_timeout_s=30)
        self._device = device
        return device

    async def long_press_ok(self) -> None:
        """Hold OK for ``HOLD_SECONDS``. Reconnects once if the kept connection went stale."""
        async with self._lock:
            for attempt in (1, 2):
                try:
                    device = await self._connected_device()
                    result = await device.shell(_LONG_PRESS_SCRIPT, read_timeout_s=5)
                    if "ok" not in (result or ""):
                        raise RuntimeError(f"unexpected reply: {result!r}")
                    return
                except Exception:  # pylint: disable=broad-exception-caught
                    await self.close()
                    if attempt == 2:
                        raise
                    _LOG.debug("ADB long press failed, reconnecting", exc_info=True)

    async def close(self) -> None:
        """Close the ADB connection."""
        if self._device is not None:
            try:
                await self._device.close()
            except Exception:  # pylint: disable=broad-exception-caught
                pass
            self._device = None
