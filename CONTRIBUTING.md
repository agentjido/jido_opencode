# Contributing to Jido.OpenCode

## Setup

```bash
cd jido_opencode
mix setup
```

## Testing

```bash
mix test                    # Run tests
mix test --include flaky    # Include flaky tests
mix coveralls.html          # Coverage report
```

## Code Quality

```bash
mix quality   # Full check: format, compile, credo, dialyzer, doctor
mix format    # Auto-format
mix credo     # Linting
mix dialyzer  # Type checking
mix doctor    # Documentation coverage
```

## Commits

Use conventional commits:

```
feat(scope): description
fix: description
docs: description
test: description
```

## Documentation

```bash
mix docs
open doc/index.html
```
