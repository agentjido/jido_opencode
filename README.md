# Jido.OpenCode

`jido_opencode` is a `jido_harness` adapter for the OpenCode CLI.

This package maps OpenCode JSON output into normalized `Jido.Harness.Event` structs and publishes runtime contract metadata for harness execution flows.

## Installation

Add dependencies:

```elixir
{:jido_harness, github: "agentjido/jido_harness", branch: "main", override: true}
{:jido_opencode, github: "agentjido/jido_opencode", branch: "main"}
```

This repo is currently aligned as part of the GitHub-based harness package set rather than a Hex release line.

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

## Package Purpose

`jido_opencode` is the OpenCode adapter package for `jido_harness`, currently scoped to Z.AI-compatible runtime/auth flows.

## Testing Paths

- Unit/contract tests: `mix test`
- Full quality gate: `mix quality`
- Optional live checks: `mix opencode.install && mix opencode.compat && mix opencode.smoke "hello"`

## Live Integration Test

`jido_opencode` includes an opt-in live adapter test that runs the real OpenCode CLI through the harness adapter path:

```bash
mix test --include integration test/jido_opencode/integration/adapter_live_integration_test.exs
```

The test auto-loads `.env` and is excluded from default `mix test` runs.

Environment knobs:

- `ZAI_API_KEY` for OpenCode auth
- `ZAI_BASE_URL` and `OPENCODE_MODEL` for custom endpoint/model selection
- `JIDO_OPENCODE_LIVE_PROMPT` to override the default prompt
- `JIDO_OPENCODE_LIVE_CWD` to override the working directory
- `JIDO_OPENCODE_LIVE_MODEL` to force a specific model
- `JIDO_OPENCODE_LIVE_TIMEOUT_MS` to extend the per-run timeout
- `JIDO_OPENCODE_REQUIRE_SUCCESS=1` to fail unless the terminal event is successful
- `JIDO_OPENCODE_CLI_PATH` to target a non-default OpenCode CLI binary
