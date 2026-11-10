#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
root="$PWD"
source release.env
mkdir -p work/downloads work/cache "dist/$ZLS_VERSION"
workdir="$(mktemp -d "$root/work/build.XXXXXX")"
dist="$root/dist/$ZLS_VERSION"

download() {
  local url="$1" hash="$2" archive="$3"
  if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 "$url" -o "$archive"
  fi
  echo "$hash  $archive" | shasum -a 256 --check
}

# CI downloads the checksum-pinned compiler. Other hosts may supply the same version.
if [[ -z "${ZIG:-}" ]]; then
  if [[ "$(uname -sm)" != "Linux x86_64" ]]; then
    echo "Set ZIG to a Zig $ZIG_VERSION executable on this host" >&2
    exit 1
  fi
  archive="$root/work/downloads/zig-$ZIG_VERSION-linux-x86_64.tar.xz"
  download "$ZIG_URL" "$ZIG_SHA256" "$archive"
  mkdir "$workdir/zig"
  tar -xf "$archive" --strip-components=1 -C "$workdir/zig"
  ZIG="$workdir/zig/zig"
fi
ZIG="$(cd "$(dirname "$ZIG")" && pwd)/$(basename "$ZIG")"
test "$("$ZIG" version)" = "$ZIG_VERSION"

archive="$root/work/downloads/zls-$ZLS_REVISION.tar.gz"
download "https://codeload.github.com/zigtools/zls/tar.gz/$ZLS_REVISION" "$ZLS_SHA256" "$archive"
mkdir "$workdir/source" "$workdir/deps"
tar -xf "$archive" --strip-components=1 -C "$workdir/source"
# Always start from fresh source: edited or removed patches cannot leave a stale tree.
patches=()
while IFS= read -r name; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  patch --batch --fuzz=0 -d "$workdir/source" -p1 < "patches/$name"
  patches+=("patches/$name")
done < patches/series
while read -r repo revision package_hash hash; do
  archive="$root/work/downloads/$package_hash.tar.gz"
  download "https://codeload.github.com/$repo/tar.gz/$revision" "$hash" "$archive"
  mkdir "$workdir/deps/$package_hash"
  tar -xf "$archive" --strip-components=1 -C "$workdir/deps/$package_hash"
done < dependencies.txt

export ZIG_LOCAL_PKG_DIR="$workdir/deps"
export ZIG_GLOBAL_CACHE_DIR="$root/work/cache/global"
zig_build() {
  "$ZIG" build --build-file "$workdir/source/build.zig" \
    --system "$workdir/deps" --cache-dir "$root/work/cache/local" "$@"
}
if [[ "${RUN_TESTS:-0}" == 1 ]]; then
  zig_build test -Doptimize=ReleaseSafe "-Dversion-string=$ZLS_VERSION"
fi
if [[ $# == 0 ]]; then
  set -- aarch64-macos x86_64-macos x86_64-linux aarch64-linux
fi
archives=()
for target in "$@"; do
  case "$target" in
    aarch64-macos|x86_64-macos|x86_64-linux|aarch64-linux) ;;
    *) echo "Unsupported target: $target" >&2; exit 1 ;;
  esac
  echo "Building $target"
  prefix="$workdir/$target"
  zig_build --prefix "$prefix" --prefix-exe-dir . \
    -Doptimize=ReleaseFast "-Dtarget=$target" "-Dversion-string=$ZLS_VERSION"
  if [[ "$target" == x86_64-linux && "$(uname -sm)" == 'Linux x86_64' ]]; then
    test "$("$prefix/zls" --version)" = "$ZLS_VERSION"
  fi
  cp "$workdir/source/LICENSE" THIRD_PARTY_NOTICES "$prefix/"
  name="zls-$target-$ZLS_VERSION.tar.xz"
  tar -cJf "$dist/$name" -C "$prefix" zls LICENSE THIRD_PARTY_NOTICES
  archives+=("$name")
done
{
  echo "source=$ZLS_REVISION"
  echo "source_sha256=$ZLS_SHA256"
  echo "version=$ZLS_VERSION"
  echo "recipe_commit=$(git rev-parse HEAD)"
  echo "zig_version=$("$ZIG" version)"
  echo "ci_zig_archive_sha256=$ZIG_SHA256"
  echo "host=$(uname -sm)"
  shasum -a 256 "$ZIG" | awk '{print $1 "  zig"}'
  shasum -a 256 release.env patches/series "${patches[@]}" dependencies.txt build.sh THIRD_PARTY_NOTICES
} > "$dist/BUILD-INFO.txt"
(cd "$dist" && shasum -a 256 "${archives[@]}" BUILD-INFO.txt > SHA256SUMS)
