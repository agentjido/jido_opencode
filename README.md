# Jido.OpenCode

`jido_opencode` is a `jido_harness` adapter for the OpenCode CLI.

This package maps OpenCode JSON output into normalized `Jido.Harness.Event` structs and publishes runtime contract metadata for harness execution flows.

## Installation

Add dependencies:

```elixir
{:jido_harness, "~> 0.1"}
{:jido_opencode, "~> 0.1"}
```

Then install deps:

```bash
mix deps.get
```

## Usage

Run directly:

```elixir
{:ok, stream} = Jido.OpenCode.run("Return exactly: OK", cwd: "/repo")
events = Enum.to_list(stream)
```

Run via harness:

```elixir
request = Jido.Harness.RunRequest.new!(%{prompt: "Summarize changes", cwd: "/repo"})
{:ok, stream} = Jido.Harness.run(:opencode, request)
```

## Runtime Requirements (Z.AI v1)

- Required env: `ZAI_API_KEY`
- Optional env:
  - `ZAI_BASE_URL` (defaulted in runtime contract to `https://api.z.ai/api/anthropic`)
  - `OPENCODE_MODEL` (defaulted to `zai_custom/glm-4.5-air`)
- CLI: `opencode` (install via `npm install -g opencode-ai`)

Helpful tasks:

```bash
mix opencode.install
mix opencode.compat
mix opencode.smoke "Return exactly: JIDO_OPENCODE_SMOKE_OK"
```

## Capability Notes

Current adapter behavior is intentionally conservative:

- `streaming?` is `false` in v1 (`run/2` is buffered-first)
- `cancellation?` is `false`
- Scope is Z.AI-focused runtime contract support

## License

Apache-2.0
