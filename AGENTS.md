# AGENTS.md - Jido OpenCode Development Guide

## Build/Test/Lint Commands

- `mix test` - Run tests (excludes flaky tests)
- `mix test path/to/specific_test.exs` - Run a single test file
- `mix test --include flaky` - Run all tests including flaky ones
- `mix quality` or `mix q` - Run full quality check (format, compile, dialyzer, credo)
- `mix format` - Auto-format code
- `mix dialyzer` - Type checking
- `mix credo` - Code analysis
- `mix coveralls` - Test coverage report
- `mix docs` - Generate documentation

## Architecture

This is an Elixir library for an **OpenCode CLI adapter** in the Jido harness ecosystem:

- **Jido.OpenCode** - Public entry module
- **Jido.OpenCode.Adapter** - `Jido.Harness.Adapter` implementation
- **Jido.OpenCode.Mapper** - OpenCode JSON to `Jido.Harness.Event` mapping
- **Jido.OpenCode.Compatibility** - CLI compatibility probes
- **Jido.OpenCode.CLI** - Command execution wrapper
- **Jido.OpenCode.Error** - Splode-based error handling

## Code Style Guidelines

- Use `@moduledoc` for module documentation following existing patterns
- TypeSpecs: Define `@type` for custom types, use strict typing throughout
- Parameter validation via Zoi schemas
- Error handling: Return `{:ok, result}` or `{:error, reason}` tuples consistently
- Testing: Use ExUnit
- Naming: Snake_case for functions/variables, PascalCase for modules

## Git Commit Guidelines

Use **Conventional Commits** format for all commit messages:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation only
- `style` - Formatting, no code change
- `refactor` - Code change that neither fixes a bug nor adds a feature
- `test` - Adding or updating tests
- `chore` - Maintenance tasks, dependency updates

**Examples:**
```
feat(query): add basic query support
fix: handle empty queries
docs: update README with examples
test(error): add error handling tests
chore(deps): update dependencies
```
