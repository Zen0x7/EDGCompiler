#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: package-edg.sh --source DIR --build DIR --target TARGET --asset NAME --output FILE

Builds a distributable EDG tarball from an edgcpp/compiler source checkout and
an existing CMake build directory.

  --source   path to edgcpp/compiler checkout
  --build    path to CMake build directory (e.g. build/gcc-release)
  --target   CMake runtime target suffix, e.g. linux_x86_64 or linux_aarch64
  --asset    asset name used for checksums (e.g. edg-linux-x64.tar.gz)
  --output   output .tar.gz path
EOF
  exit 2
}

SRC=""
BUILD=""
TARGET=""
ASSET=""
OUTPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SRC="${2:-}"; shift 2 ;;
    --build) BUILD="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --asset) ASSET="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

[ -n "$SRC" ] && [ -n "$BUILD" ] && [ -n "$TARGET" ] && [ -n "$ASSET" ] && [ -n "$OUTPUT" ] || usage

require_file() {
  if [ ! -f "$1" ]; then
    echo "missing required file: $1" >&2
    exit 1
  fi
}

require_exec() {
  if [ ! -x "$1" ]; then
    echo "missing required executable: $1" >&2
    exit 1
  fi
}

require_file "$SRC/LICENSE.txt"
require_file "$SRC/util/eccp.sh"
require_file "$SRC/dev_tools/bin/edg-scrape-compiler"
require_file "$SRC/bases/docker/dev-env/gcc/edg_eccp_config"
require_file "$SRC/bases/docker/dev-env/gcc/lib/predefined_macros.txt"
require_file "$SRC/include_c++/README"
require_file "$SRC/include_c99/iso646.h"
for b in cpfe cpfe-cp cdisp dettarg mk_errinfo edg_decode edg_munch edg_prelink; do
  require_exec "$BUILD/bin/$b"
done
require_file "$BUILD/lib/libC.a"
if [ ! -d "$BUILD/lib_${TARGET}" ]; then
  echo "missing runtime output directory: $BUILD/lib_${TARGET}" >&2
  exit 1
fi
require_file "$BUILD/lib_${TARGET}/libC.a"

PKGROOT=""
cleanup() {
  [ -n "$PKGROOT" ] && rm -rf "$PKGROOT"
}
trap cleanup EXIT

PKGROOT="$(mktemp -d)"
PKG="$PKGROOT/edg"
mkdir -p "$PKG/bin" "$PKG/lib" "$PKG/lib_${TARGET}"

install -m 0755 "$SRC/util/eccp.sh" "$PKG/bin/eccp"
install -m 0755 "$SRC/dev_tools/bin/edg-scrape-compiler" "$PKG/bin/edg-scrape-compiler"
for b in cpfe cpfe-cp cdisp dettarg mk_errinfo edg_decode edg_munch edg_prelink; do
  install -m 0755 "$BUILD/bin/$b" "$PKG/bin/$b"
done

ln -s cpfe "$PKG/bin/cfe"
ln -s cpfe "$PKG/bin/edgcpfe"
ln -s cdisp "$PKG/bin/edgcpdisp"

cp -a "$SRC/include_c++" "$PKG/include"
cp -a "$SRC/include_c99" "$PKG/include_c99"
if [ "$TARGET" = "linux_aarch64" ]; then
  cp "$SRC/bases/docker/dev-env/gcc/edg_eccp_config" "$PKG/edg_eccp_config"
  printf '\nEDG_C_TO_OBJ_DEFAULT_OPTIONS="$EDG_C_TO_OBJ_DEFAULT_OPTIONS -D__float128=_Float128"\n' >> "$PKG/edg_eccp_config"
  printf '\nEDG_C_TO_OBJ_DEFAULT_OPTIONS_linux_aarch64="$EDG_C_TO_OBJ_DEFAULT_OPTIONS_linux_aarch64 -D__float128=_Float128"\n' >> "$PKG/edg_eccp_config"
  chmod 0444 "$PKG/edg_eccp_config"
else
  install -m 0444 "$SRC/bases/docker/dev-env/gcc/edg_eccp_config" "$PKG/edg_eccp_config"
fi
install -m 0644 "$SRC/bases/docker/dev-env/gcc/lib/predefined_macros.txt" "$PKG/lib/predefined_macros.txt"
install -m 0644 "$SRC/bases/docker/dev-env/gcc/lib/predefined_macros.txt" "$PKG/lib_${TARGET}/predefined_macros.txt"
install -m 0644 "$BUILD/lib/libC.a" "$PKG/lib/libC.a"
install -m 0644 "$BUILD/lib_${TARGET}/libC.a" "$PKG/lib_${TARGET}/libC.a"
install -m 0644 "$SRC/LICENSE.txt" "$PKG/LICENSE.txt"

edg_repo="${EDG_REPOSITORY:-https://github.com/edgcpp/compiler}"
edg_ref="${EDG_REF:-unknown}"
edg_sha="${EDG_SHA:-unknown}"
{
  echo "EDG repository: $edg_repo"
  echo "EDG ref: $edg_ref"
  echo "EDG commit: $edg_sha"
  echo "EDG source build target: $TARGET"
  echo "Asset: $ASSET"
  echo "Built at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$PKG/BUILD-INFO.txt"

mkdir -p "$(dirname "$OUTPUT")"
tar -czf "$OUTPUT" -C "$PKGROOT" edg
sha_line="$(sha256sum "$OUTPUT")"
echo "${sha_line%% *}  $ASSET" > "${OUTPUT}.sha256"
echo "wrote $OUTPUT"
