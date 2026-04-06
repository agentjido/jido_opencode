# Jido.OpenCode

`jido_opencode` is a `jido_harness` adapter for the OpenCode HTTP API.

This package communicates with the OpenCode server on port 4096 via streaming HTTP API, translating SSE events into normalized `Jido.Harness.Event` structs. Supports multi-provider configuration (OpenAI, Anthropic, Z.AI, Gemini, etc.).

## Features

- **Streaming**: Real-time SSE streaming with `streaming?: true`
- **Multi-Provider**: Support for OpenAI, Anthropic, Z.AI, Gemini, and more
- **Tool Calls**: Function calling and tool use support
- **Cancellation**: Cancel active streaming sessions via `SessionRegistry`
- **Usage Tracking**: Token usage reporting in events

## Installation

Add dependencies:

```elixir
{:jido_harness, "~> 0.1"}
{:jido_opencode, "~> 0.2"}
```

Then install deps:

```bash
mix deps.get
```

## Prerequisites

Ensure the OpenCode server is running:

```bash
opencode server --port 4096
```

Or verify it's running:

```elixir
Jido.OpenCode.server_running?()
# => true
```

## Usage

Run directly with streaming:

```elixir
{:ok, stream} = Jido.OpenCode.run("Return exactly: OK", cwd: "/repo")

# Process events as they arrive
Enum.each(stream, fn event ->
  IO.inspect(event.type)
  IO.inspect(event.payload)
end)
```

Run via harness:

```elixir
request = Jido.Harness.RunRequest.new!(%{prompt: "Summarize changes", cwd: "/repo"})
{:ok, stream} = Jido.Harness.run(:opencode, request)
```

Cancel a session:

```elixir
Jido.OpenCode.cancel_session(session_id)
```

## Multi-Provider Configuration

Configure your preferred provider:

```elixir
# OpenAI
{:ok, stream} = Jido.OpenCode.run(
  "Analyze this code",
  cwd: "/repo",
  model: "gpt-4",
  provider: %{provider: "openai"}
)

# Anthropic
{:ok, stream} = Jido.OpenCode.run(
  "Analyze this code",
  cwd: "/repo",
  model: "claude-3-opus",
  provider: %{provider: "anthropic"}
)

# Z.AI
{:ok, stream} = Jido.OpenCode.run(
  "Analyze this code",
  cwd: "/repo",
  model: "zai_custom/glm-4.5-air",
  provider: %{
    provider: "zai_custom",
    baseURL: System.get_env("ZAI_BASE_URL"),
    apiKey: System.get_env("ZAI_API_KEY")
  }
)
```

## Runtime Requirements

- OpenCode server running on port 4096
- One of: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `ZAI_API_KEY`, or `GEMINI_API_KEY`
- Optional: `OPENCODE_MODEL` environment variable

## Capability Notes

- `streaming?` is `true` - Real-time SSE streaming
- `tool_calls?` is `true` - Function calling supported
- `cancellation?` is `true` - Cancel active sessions
- `multiple_models?` is `true` - Multi-provider support
- `usage_tracking?` is `true` - Token usage in events

## License

Apache-2.0

## Package Purpose

`jido_opencode` is the OpenCode adapter package for `jido_harness`, providing HTTP API-based streaming with multi-provider support.

## Testing Paths

- Unit/contract tests: `mix test`
- Full quality gate: `mix quality`
- Server check: `mix opencode.check`
