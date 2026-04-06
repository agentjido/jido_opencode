defmodule Jido.OpenCode do
  @moduledoc """
  OpenCode HTTP API adapter package for `Jido.Harness`.

  This package provides a provider adapter (`Jido.OpenCode.Adapter`) that
  communicates with the OpenCode server on port 4096 via streaming HTTP API.

  ## Features

  - **Streaming**: Real-time SSE streaming support
  - **Multi-Provider**: Support for OpenAI, Anthropic, Z.AI, Gemini, and more
  - **Tool Calls**: Function calling and tool use support
  - **Cancellation**: Cancel active streaming sessions
  - **Usage Tracking**: Token usage reporting

  ## Setup

  Ensure the OpenCode server is running:

      opencode server --port 4096

  Or check if it's running:

      Jido.OpenCode.server_running?()
  """

  @version "0.2.0"

  alias Jido.Harness.RunRequest
  alias Jido.OpenCode.{Adapter, Client, Compatibility}

  @doc "Returns the package version."
  @spec version() :: String.t()
  def version, do: @version

  @doc "Returns true when the OpenCode server is running on port 4096."
  @spec server_running?(keyword()) :: boolean()
  def server_running?(opts \\ []) when is_list(opts) do
    Client.server_running?(opts)
  end

  @doc "Returns true when the OpenCode CLI can be resolved."
  @spec cli_installed?(keyword()) :: boolean()
  def cli_installed?(opts \\ []) when is_list(opts) do
    Compatibility.cli_installed?(opts)
  end

  @doc "Returns true when local OpenCode server is running and compatible."
  @spec compatible?(keyword()) :: boolean()
  def compatible?(opts \\ []) when is_list(opts) do
    Compatibility.compatible?(opts)
  end

  @doc "Raises when OpenCode server is not running or incompatible."
  @spec assert_compatible!(keyword()) :: :ok | no_return()
  def assert_compatible!(opts \\ []) when is_list(opts) do
    Compatibility.assert_compatible!(opts)
  end

  @doc """
  Cancel an active streaming session.

  ## Examples

      iex> Jido.OpenCode.cancel_session("session-uuid")
      :ok
  """
  @spec cancel_session(String.t()) :: :ok | {:error, term()}
  def cancel_session(session_id) when is_binary(session_id) do
    Adapter.cancel_session(session_id)
  end

  @doc """
  Runs an OpenCode prompt and returns a normalized harness event stream.

  ## Options

    * `:cwd` - Working directory for the prompt context
    * `:model` - Model to use (e.g., "gpt-4", "claude-3-opus", "zai_custom/glm-4.5-air")
    * `:timeout_ms` - Request timeout in milliseconds (default: 300000)
    * `:host` - OpenCode server host (default: "localhost")
    * `:port` - OpenCode server port (default: 4096)
    * `:provider` - Provider configuration map for multi-provider support
    * `:tools` - Tool definitions for function calling

  ## Examples

      # Basic usage
      {:ok, stream} = Jido.OpenCode.run("Summarize this code", cwd: "/path/to/repo")
      Enum.to_list(stream)

      # With specific model
      {:ok, stream} = Jido.OpenCode.run(
        "Analyze this",
        cwd: "/path/to/repo",
        model: "claude-3-opus"
      )
  """
  @spec run(String.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  def run(prompt, opts \\ []) when is_binary(prompt) and is_list(opts) do
    attrs = %{
      prompt: prompt,
      cwd: opts[:cwd],
      model: opts[:model],
      timeout_ms: opts[:timeout_ms],
      metadata: opts[:metadata] || %{}
    }

    with {:ok, request} <- RunRequest.new(attrs) do
      adapter_module().run(request, opts)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Backward-compatible prompt API.

  Delegates to `run/2` and returns normalized events.
  """
  @spec query(String.t()) :: {:ok, Enumerable.t()} | {:error, term()}
  def query(prompt) when is_binary(prompt), do: run(prompt, [])

  defp adapter_module do
    Application.get_env(:jido_opencode, :adapter_module, Adapter)
  end
end
