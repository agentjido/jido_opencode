# Usage Rules for AI Agents (Cursor, GitHub Copilot, etc.)

This document defines constraints and best practices for AI coding agents working on this codebase.

## Core Principles

1. **Follow AGENTS.md** - Commands, architecture, style guidelines, and git conventions are in `AGENTS.md`
2. **Follow GENERIC_PACKAGE_QA.md** - Quality standards from the parent workspace
3. **Never break tests** - All existing tests must pass
4. **Type safety** - Use proper `@spec` annotations
5. **Documentation** - Every public function needs `@doc` and module needs `@moduledoc`

## Commands You Can Run

```bash
mix test                      # Run tests
mix quality                   # Full quality check
mix format                    # Auto-format
mix docs                      # Generate docs
```

## Do NOT

- Commit directly to the main branch
- Change Elixir version constraints without justification
- Remove test coverage
- Add undocumented public functions
- Use deprecated patterns (check GENERIC_PACKAGE_QA.md)

## Commit Messages

Always use conventional commits. Examples:

```
feat(module): add new functionality
fix(issue): resolve specific bug
docs: update documentation
test: add test coverage
chore(deps): update dependencies
```

Never use "WIP", "Temp", or unclear messages.

## Code Organization

- `lib/jido_opencode/` - Main library code
- `test/` - Unit tests
- `test/support/` - Test helpers and fixtures
- Keep modules focused and small

## Error Handling

Use `Jido.OpenCode.Error` module for all exceptions:

```elixir
raise Jido.OpenCode.Error.validation_error("Invalid input", %{field: "name"})
```

## Documentation Examples

Module docs should include:
- Clear description of purpose
- Usage examples with `iex>` blocks
- Parameter descriptions
- Return value descriptions

Function docs should include:
- Purpose
- Parameters (with types)
- Returns (with types)
- Examples (if complex)
