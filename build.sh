#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
: "${ZIG:?Set ZIG to the Zig 0.17.1 executable}"
ZIG="$(cd "$(dirname "$ZIG")" && pwd)/$(basename "$ZIG")"
test "$("$ZIG" version)" = 0.17.1
version=0.17.0+bazel.bbd60390
source_revision=542462c4ddf045493fa9ca028ee6bc3f38b2754a
mkdir -p work/downloads work/source work/deps dist
fetch() {
  local url="$1" hash="$2" archive="$3" destination="$4"
  if [[ ! -f "$archive" ]]; then curl --fail --location --retry 3 "$url" -o "$archive"; fi
  echo "$hash  $archive" | shasum -a 256 --check
  tar -xzf "$archive" --strip-components=1 -C "$destination"
}
if [[ ! -f work/source/.patched ]]; then
  fetch "https://codeload.github.com/zigtools/zls/tar.gz/$source_revision" \
    3eb3107317ef948783cdc3daae07238f1fe7c6cf28fe8ed1a776ff38df781224 \
    work/downloads/zls.tar.gz work/source
  patch -d work/source -p1 < path-fix.patch
  touch work/source/.patched
fi
while read -r repo revision package_hash hash; do
  mkdir -p "work/deps/$package_hash"
  fetch "https://codeload.github.com/$repo/tar.gz/$revision" "$hash" \
    "work/downloads/$package_hash.tar.gz" "work/deps/$package_hash"
done < dependencies.txt
{
  echo "source=$source_revision"
  echo 'patch=bbd60390ffc1c12cd1aa91688fd2940b22966ee9'
  echo "version=$version"
  echo "zig_version=$("$ZIG" version)"
  echo "host=$(uname -sm)"
  shasum -a 256 "$ZIG" | awk '{print $1 "  zig"}'
  shasum -a 256 path-fix.patch dependencies.txt build.sh THIRD_PARTY_NOTICES
} > dist/BUILD-INFO.txt
for target in aarch64-macos x86_64-macos x86_64-linux aarch64-linux; do
  echo "Building $target"
  mkdir -p "work/$target"
  ZIG_LOCAL_PKG_DIR="$PWD/work/deps" ZIG_GLOBAL_CACHE_DIR="$PWD/work/cache/global" \
    "$ZIG" build --build-file "$PWD/work/source/build.zig" \
    --system "$PWD/work/deps" --cache-dir "$PWD/work/cache/local" \
    --prefix "$PWD/work/$target" --prefix-exe-dir . \
    -Doptimize=ReleaseFast "-Dtarget=$target" "-Dversion-string=$version"
  cp work/source/LICENSE "work/$target/LICENSE"
  cp THIRD_PARTY_NOTICES "work/$target/THIRD_PARTY_NOTICES"
  tar -cJf "dist/zls-$target-$version.tar.xz" -C "work/$target" zls LICENSE THIRD_PARTY_NOTICES
done
(cd dist && shasum -a 256 ./*.tar.xz > SHA256SUMS)
