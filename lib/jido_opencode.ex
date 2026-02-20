defmodule Jido.OpenCode do
  @moduledoc """
  OpenCode CLI adapter package for `Jido.Harness`.

  This package provides a provider adapter (`Jido.OpenCode.Adapter`) and
  convenience helpers for runtime compatibility checks.
  """

  @version "0.1.0"

  alias Jido.Harness.RunRequest
  alias Jido.OpenCode.{Adapter, CLI, Compatibility}

  @doc "Returns the package version."
  @spec version() :: String.t()
  def version, do: @version

  @doc "Returns true when the OpenCode CLI can be resolved."
  @spec cli_installed?(keyword()) :: boolean()
  def cli_installed?(opts \\ []) when is_list(opts) do
    match?({:ok, _}, CLI.resolve(opts))
  end

  @doc "Returns true when local OpenCode CLI supports JSON run mode."
  @spec compatible?(keyword()) :: boolean()
  def compatible?(opts \\ []) when is_list(opts) do
    Compatibility.compatible?(opts)
  end

  @doc "Raises when local OpenCode CLI is incompatible."
  @spec assert_compatible!(keyword()) :: :ok | no_return()
  def assert_compatible!(opts \\ []) when is_list(opts) do
    Compatibility.assert_compatible!(opts)
  end

  @doc """
  Runs an OpenCode prompt and returns a normalized harness event stream.
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
