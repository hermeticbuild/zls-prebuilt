# ZLS prebuilts

Temporary HermeticBuild distribution of ZLS 0.17.0 with the upstream
[absolute-path correction](https://github.com/zigtools/zls/commit/bbd60390ffc1c12cd1aa91688fd2940b22966ee9).
Source: [542462c4](https://github.com/zigtools/zls/tree/542462c4ddf045493fa9ca028ee6bc3f38b2754a).
The binary version is `0.17.0+bazel.bbd60390`; it supports Zig 0.17.0 and 0.17.1.
Current upstream HEAD requires Zig 0.18 development and is deliberately not used.

Build locally with Zig 0.17.1:

```sh
ZIG=/absolute/path/to/zig ./build.sh
```

The script verifies downloaded source/dependency hashes, applies the checked-in
upstream backport, and builds x86_64/aarch64 Linux/macOS archives. Each archive
contains `zls`, its license, and third-party notices. `dist/` contains SHA-256 checksums and build
provenance. Archives are directly consumable by rules_zig's existing `zls.index`
and `zls.toolchain` extension tags; no custom build rule is needed.

This initial release is built locally. Automated builds, pinned workflow
dependencies, and attestations are follow-up work; no attestation is claimed.
