# SpinningDonut

A pure **x86-64 Linux assembly** spinning torus renderer for terminal output — no C runtime, no libc, just syscalls and math.

## Highlights

- Pure assembly (`src/main.asm`) with direct Linux syscalls
- Dynamic terminal-size rendering (with bounds clamping for safety)
- Z-buffered ASCII shading
- Mouse tracking support (when your terminal supports xterm mouse reporting)
- Reproducible build flow via `Makefile`
- GitHub Actions CI for build + smoke test
- Manual-trigger GitHub Release pipeline with packaged binaries + SHA256 checksums
- Hardened runtime error handling and safe terminal cleanup paths

## Demo

Run the app and enjoy the rotating donut in your terminal:

- Build: `make build`
- Run: `make run`

Exit with `Ctrl+C`.

## Requirements

- Linux (x86-64)
- `gcc` (used as assembler/linker driver)
- `make`
- `timeout` (for smoke test target)

## Build & Test

```bash
make build
make smoke-test
```

`make smoke-test` runs the renderer briefly to validate that it starts correctly.

For full, release-grade validation:

```bash
make verify
```

This performs a clean rebuild, runtime smoke checks, output sanity checks, artifact packaging, and checksum verification.

## Build Targets

- `make build` — build static binary
- `make run` — run interactive renderer
- `make smoke-test` — short non-interactive runtime test
- `make verify` — comprehensive validation pipeline
- `make workflow-test` — workflow lint + local release simulation
- `make package` — generate release artifacts in `dist/`
# SpinningDonut

**SpinningDonut v1.0.0** is a pure x86-64 Linux assembly torus renderer for the terminal.

No libc. No runtime framework. Just syscalls, floating-point math, z-buffering, and a very overengineered ASCII donut.

## Features

- Pure assembly renderer in `src/main.asm`
- Dynamic terminal sizing with safety clamping
- Z-buffered shading using luminance ramp characters
- Optional mouse-driven angle interaction (terminal-dependent)
- Hardened syscall/error handling and safe terminal state restoration
- Static output binary built with reproducible Make targets

## Quick Start

```bash
make build
make run
```

Exit with `Ctrl+C`.

## Requirements

- Linux (x86-64)
- `gcc`
- `make`
- `timeout` (used by smoke validation)

## Build & Validation

```bash
make build
make smoke-test
make verify
```

- `make build` builds the static executable
- `make smoke-test` runs a short runtime check
- `make verify` runs the full validation pipeline

## Controls

- `Ctrl+C`: quit
- Mouse movement: adjusts rotation angles when terminal mouse reporting is available

## Project Layout

- `src/main.asm` — renderer and runtime
- `Makefile` — build/run/validation/package targets
- `scripts/validate.sh` — strict local validation script
- `CONTRIBUTING.md` — contribution guidelines
- `SECURITY.md` — security reporting policy
- `CHANGELOG.md` — release history
- `LICENSE` — MIT

## Publishing Checklist

Before publishing to GitHub (`naviNBRuas`):

1. Run `make clean && make verify`
2. Commit source and documentation updates
3. Tag the release as `v1.0.0`
4. Publish release artifacts

## License

Licensed under the MIT License. See `LICENSE`.
