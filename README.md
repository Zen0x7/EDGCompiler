# Setup EDG Compiler

GitHub Action to install prebuilt EDG front-end binaries and optionally run one.

The release workflow builds Linux `x64` and `arm64` archives from the open-source EDG repository (`edgcpp/compiler`) and publishes them as release assets. The action downloads the right archive for the runner, verifies `SHA256SUMS`, and adds the EDG bin directory to `PATH`.

## Usage

Install and run `eccp`:

```yaml
- uses: Zen0x7/EDGCompiler@v1
  with:
    tool: eccp
    args: --version
```

Install only, then call EDG in later steps:

```yaml
- uses: Zen0x7/EDGCompiler@v1

- run: eccp -c src/main.cpp -o main.o
- run: edgcpfe --version
```

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `release` | `latest` | Release tag to download, or `latest`. |
| `repository` | `Zen0x7/EDGCompiler` | Repository hosting the release assets. |
| `system-headers` | `true` | Use the runner's GCC C/C++ include paths. Required for normal C++ compilation. |
| `tool` | empty | Binary to run after install. Empty means install only. |
| `args` | empty | Whitespace-separated args for `tool`. Quotes are not re-parsed. |
| `working-directory` | `.` | Directory to run `tool` in. |

## Outputs

| Output | Description |
| --- | --- |
| `edg-root` | Path to the EDG installation root. |
| `edg-bin` | Path to the EDG `bin` directory. |

## Environment

The action sets `EDG_HOME`, `EDG_BASE`, `ECCP_LIBDIR`, `ECCP`, `CPFE`, `CPFE_CP`, `EDG_MUNCH_PATH`, `EDG_DECODE_PATH` and `EDG_PRELINK_PATH`. With `system-headers: true` it also sets `EDG_USE_SYSTEM_HEADERS=1` and `EDG_GCC_INCL_SCRAPE` / `EDG_GCC_CINCL_SCRAPE` / `EDG_GCC_VER_SCRAPE`.

## Releases

`release` builds `edg-linux-x64.tar.gz` and `edg-linux-arm64.tar.gz`, generates `SHA256SUMS`, and creates/updates a GitHub release.

- Push a tag `v*` to build and publish that tag.
- Or use **Actions → release → Run workflow** and pass `tag` and optionally `edg_ref`.

EDG is built from `edgcpp/compiler`, which is licensed under Apache-2.0 with LLVM exceptions. See `LICENSE.txt` inside each archive.
