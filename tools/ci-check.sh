#!/bin/sh
# Fork: the checks every PR, push and upstream sync must pass. The original's lint
# (.github/workflows/python-code-format.yml: pylint, isort, black), then the aarch64 build with
# tools/build-aarch64-proot.sh, then a check that the build bundled every system library an
# official release bundles (the first proot build had none and died on the remote).
#
# Needs: docker, proot, qemu-user-static, python3. Run from the repository root.
# Output: uc-intg-dunehd-v<version>-aarch64.tar.gz in the repository root.
set -eu

# `run_container` can exit 125 inside an LXC when removing the finished container fails
# ("unable to remove filesystem"), even though the command in it succeeded. Run without --rm,
# keep the command's exit code, and remove the container best-effort.
run_container() {
  name=ci-build-$$-$(date +%s%N)
  rc=0
  docker run --name "$name" "$@" || rc=$?
  docker rm -f "$name" >/dev/null 2>&1 || true
  return "$rc"
}

PY_IMAGE=docker.io/library/python:3.11-slim-bookworm@sha256:eb769d88622468aea09986df8172151981bf6622b5eec58dc38301e20673ff84
# Official release used as the reference for bundled system libraries
REF_URL=https://github.com/petercv/ucr2-integration-dunehd/releases/download/v0.2.2/uc-intg-dunehd-v0.2.2-aarch64.tar.gz
REF_SHA=c093ede359f3a0282413cdbae3af564d91f184873e8b4a12f5878eb6d3f51e0e
CACHE=${BUILD_CACHE:-$HOME/.cache/dunebuild}
mkdir -p "$CACHE/pip"

run_container -v "$CACHE/pip:/root/.cache/pip" -v "$PWD:/w" -w /w "$PY_IMAGE" \
  sh -c "pip install -q --root-user-action=ignore -r requirements.txt -r test-requirements.txt &&
         python -m pylint src &&
         python -m isort src/. --check &&
         python -m black src --check --line-length 120"

rm -f uc-intg-dunehd-v*-aarch64.tar.gz
tools/build-aarch64-proot.sh "$CACHE"
ARCHIVE=$(ls uc-intg-dunehd-v*-aarch64.tar.gz)

REF=$CACHE/reference.tar.gz
if ! echo "$REF_SHA  $REF" | sha256sum -c - >/dev/null 2>&1; then
  curl -fsSL "$REF_URL" -o "$REF"
  echo "$REF_SHA  $REF" | sha256sum -c -
fi
libs() { tar tzf "$1" | sed -n 's|.*/\(lib[^/]*\.so[.0-9]*\)$|\1|p' | sort -u; }
libs "$REF" > "$CACHE/reference-libs"
libs "$ARCHIVE" > "$CACHE/built-libs"
missing=$(comm -23 "$CACHE/reference-libs" "$CACHE/built-libs")
if [ -n "$missing" ]; then
  echo "$ARCHIVE lacks system libraries the official release bundles:" >&2
  echo "$missing" >&2
  exit 1
fi
echo "$ARCHIVE bundles all $(wc -l < "$CACHE/reference-libs") system libraries of the official release"
