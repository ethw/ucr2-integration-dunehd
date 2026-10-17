#!/bin/sh
# Builds the on-device (aarch64) integration archive on an x86_64 Linux host without Docker
# binfmt/QEMU registration (e.g. an unprivileged LXC): Unfolded Circle's r2-pyinstaller image is
# exported to a rootfs and run under proot + qemu-user. Same steps as .github/workflows/build.yml.
#
# Needs: docker (only to pull/export the image), proot, qemu-user-static.
# Usage: tools/build-aarch64-proot.sh [workdir]    (run from the repository root)
# Output: uc-intg-dunehd-v<version>-aarch64.tar.gz in the repository root.
#
# Two emulation workarounds, both build-time only:
# - os.access() reports false for every file under proot + qemu, so PyInstaller's
#   shutil.which("objdump") check fails; the build treats existence as access.
# - The real ldd cannot trace under the emulated loader ("not a dynamic executable"), so
#   PyInstaller would silently bundle no system libraries (libffi, libssl, libz, ...) and the
#   driver dies on the remote with "libffi.so.7: cannot open shared object file". ldd is
#   replaced in the rootfs by objdump (DT_NEEDED) + ldconfig resolution in ldd's format.
#   Check the result: compare the bundled *.so list with an official release archive.
set -e
PYTHON_VER=3.11.13-0.4.0
IMAGE=docker.io/unfoldedcircle/r2-pyinstaller:$PYTHON_VER
SRC=$(pwd)
WORK=${1:-$HOME/dunebuild}
ROOTFS=$WORK/rootfs-$PYTHON_VER

if [ ! -d "$ROOTFS" ]; then
  mkdir -p "$ROOTFS"
  docker pull -q --platform linux/arm64 "$IMAGE"
  cid=$(docker create --platform linux/arm64 "$IMAGE" true)
  docker export "$cid" | tar -x -C "$ROOTFS"
  docker rm "$cid" >/dev/null
  mv "$ROOTFS/usr/bin/ldd" "$ROOTFS/usr/bin/ldd.orig"
  cat > "$ROOTFS/usr/bin/ldd" <<'EOF'
#!/bin/sh
# Build-only stand-in for ldd under proot + qemu-user (see tools/build-aarch64-proot.sh).
for f in "$@"; do
  [ $# -gt 1 ] && echo "$f:"
  objdump -p "$f" 2>/dev/null | awk '/NEEDED/{print $2}' | while read -r lib; do
    path=$(/sbin/ldconfig -p | awk -v l="$lib" '$1==l && /AArch64/{print $NF; exit}')
    [ -z "$path" ] && for d in /usr/local/lib /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu; do
      [ -e "$d/$lib" ] && path="$d/$lib" && break
    done
    if [ -n "$path" ]; then echo "	$lib => $path (0x0000000000000000)"; else echo "	$lib => not found"; fi
  done
done
EOF
  chmod +x "$ROOTFS/usr/bin/ldd"
fi

cat > "$WORK/inner-build.sh" <<'EOF'
set -e
cd /workspace
python -m pip install -q -r requirements.txt
python - <<'PY'
import os, sys
os.access = lambda path, mode, *a, **k: os.path.exists(path)
sys.argv = ["pyinstaller", "--collect-submodules", "zeroconf", "--clean", "--onedir", "--name", "driver", "src/driver.py"]
from PyInstaller.__main__ import run
run()
PY
rm -rf artifacts && mkdir -p artifacts/bin
cp -r dist/driver/* artifacts/bin
cp driver.json artifacts/
echo "v$(python -c 'import json; print(json.load(open("driver.json"))["version"])')" > artifacts/version.txt
tar czf "uc-intg-dunehd-$(cat artifacts/version.txt)-aarch64.tar.gz" -C artifacts .
EOF

proot -q qemu-aarch64-static -r "$ROOTFS" -b /dev -b /proc -b /etc/resolv.conf \
  -b "$SRC:/workspace" -b "$WORK/inner-build.sh:/inner-build.sh" -w /workspace \
  /usr/bin/env -i PATH=/home/builder/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  HOME=/tmp LANG=C.UTF-8 sh /inner-build.sh

ls -la "$SRC"/uc-intg-dunehd-v*-aarch64.tar.gz
