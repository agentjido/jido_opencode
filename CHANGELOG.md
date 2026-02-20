# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-02-20

### Added

- `Jido.OpenCode.Adapter` implementing `Jido.Harness.Adapter`
- OpenCode runtime stack modules (`CLI`, `Compatibility`, `Options`, `Mapper`, `SystemCommand`)
- Mix tasks: `opencode.install`, `opencode.compat`, `opencode.smoke`
- Runtime contract metadata for harness exec flows (Z.AI-focused v1)
- Shared adapter contract conformance test usage in adapter tests

### Changed

- `Jido.OpenCode.run/2` is now the primary execution API
- `Jido.OpenCode.query/1` now delegates to real adapter execution semantics
