# Jido.OpenCode

OpenCode CLI integration for the Jido Agent framework.

## Installation

Add to `mix.exs`:

```elixir
{:jido_opencode, "~> 0.1"}
```

Then run:

```bash
mix deps.get
```

## Quick Start

```elixir
{:ok, result} = Jido.OpenCode.query("Analyze this codebase")
```

## Documentation

Full documentation is available at [https://hexdocs.pm/jido_opencode](https://hexdocs.pm/jido_opencode)

## License

Apache-2.0
