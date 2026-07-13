# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Fixed
- Critical: the frame-flush write clobbered the `SYS_WRITE` syscall number with the screen dimensions before issuing the syscall, so the rendered torus was never actually written to the terminal (only the clear-screen escape sequence was emitted each frame).
- Syscall error checks (`js` after `syscall`) were testing stale flags left over from earlier arithmetic instead of the syscall's actual return value, since `syscall`/`sysret` do not derive flags from `rax`. All syscall sites now `test rax, rax` immediately before branching on error.
- Removed unused `src/entry.S`, a dead C-runtime-style entry stub that called a nonexistent `main` and was never referenced by the build.
- `scripts/test-workflows.sh` copied the real repository's `.git` directory (including its configured `origin` remote) into its local release simulation sandbox, causing `git remote add origin` to fail; the simulation now excludes `.git` and builds a clean throwaway repo. Also added a tag message so local simulated tagging works under `tag.gpgsign` configurations.

## [1.0.0] - 2026-04-03

### Added
- Initial public release of SpinningDonut.
- Pure x86-64 assembly renderer with direct Linux syscalls.
- Dynamic terminal sizing, ASCII luminance shading, and z-buffered rendering.
- Make-based build, smoke-test, verification, and packaging targets.
- Contributor, security, and repository governance documentation.

### Changed
- Hardened terminal setup/cleanup and syscall failure paths.
- Improved runtime behavior for non-interactive execution contexts.
- Refined documentation for release and publishing readiness.

### Fixed
- Validation reliability across interactive and non-interactive environments.
- Smoke-test timeout behavior for continuously running render loop.
