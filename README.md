# ZLS prebuilts

HermeticBuild releases of [ZLS](https://github.com/zigtools/zls), built from pinned
upstream revisions with a maintained patch series. Releases are available for
x86_64 and aarch64 on Linux and macOS. Compilation uses upstream ZLS's
`build.zig`; this repository adds input pinning, patches, packaging and publication.

## Build locally

On Linux x86_64, `./build.sh` downloads and verifies the compiler pinned in
`release.env`. On another host, supply that Zig version explicitly:

```sh
ZIG=/absolute/path/to/zig RUN_TESTS=1 ./build.sh
# Build a subset:
ZIG=/absolute/path/to/zig ./build.sh aarch64-macos
```

`RUN_TESTS=1` runs upstream's native test step before building. Outputs go to
`dist/<version>/`. Each archive contains `zls` at its root, `LICENSE` and
`THIRD_PARTY_NOTICES`. Source and dependencies are checksum-verified; patches
are applied in `patches/series` order to a fresh tree on every build. The Zig
build uses the downloaded package closure with fetching disabled.

## Publish a release

1. Update `release.env` with the distribution version, upstream revision and
   checksum, and compatible Zig version and Linux compiler checksum.
2. Update `dependencies.txt` from upstream's package manifest when needed.
   Update `THIRD_PARTY_NOTICES` alongside dependency changes.
3. Add or remove patches in `patches/` and update `patches/series`.
4. Push the recipe to main and let the build and upstream tests pass.
5. Create and push a tag matching `ZLS_VERSION` in `release.env`.

The workflow cross-builds all four targets on a GitHub-hosted Ubuntu runner.
Pull requests, main pushes and manual runs build and test without publishing.
Only tag pushes can sign and publish. Compilation has read-only permissions;
attestation and publication run in separate jobs. Every action is pinned to a
full commit SHA, and the CI compiler, source and package downloads have SHA-256
pins. Dependabot proposes action updates.

Tag builds generate GitHub/Sigstore build-provenance attestations. Publication
verifies checksums and attestations against this workflow, tag and source commit,
then publishes a draft with all assets attached. Existing releases are never
overwritten: bump the distribution version for every published build.

Cross-compilation does not establish runtime compatibility on every platform.
The workflow runs the upstream tests natively on Linux x86_64; downstream
integration tests should exercise their own SDK and platform combinations.

## Verify downloads

Download the archives, `SHA256SUMS`, `BUILD-INFO.txt` and `provenance.jsonl` from
the same release. Verify checksums and signed provenance:

```sh
shasum -a 256 --check SHA256SUMS
gh attestation verify zls-<target>-<version>.tar.xz \
  --repo hermeticbuild/zls-prebuilt \
  --bundle provenance.jsonl --deny-self-hosted-runners \
  --signer-workflow hermeticbuild/zls-prebuilt/.github/workflows/release.yml \
  --source-ref 'refs/tags/<version>'
```

`SHA256SUMS` covers all archives and build information, so download all listed
files when checking the complete manifest. `BUILD-INFO.txt` records the recipe
commit, source revision, compiler identity, and patch/dependency hashes.

The initial `0.17.0+bazel.bbd60390` release was built manually and has no CI
attestation. Its bytes remain unchanged. CI releases begin with
`0.17.0+hermetic.1`.

## Consumers

The current recipe targets Zig 0.17.0 and 0.17.1 and includes the upstream
[absolute-path correction](https://github.com/zigtools/zls/commit/bbd60390ffc1c12cd1aa91688fd2940b22966ee9).
For rules_zig, add the release URLs and checksums to a `zls.index` file, then
select its version through `zls.toolchain`. These are regular prebuilt ZLS
executables and can also be used independently of Bazel.
