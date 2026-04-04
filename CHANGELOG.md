# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

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
