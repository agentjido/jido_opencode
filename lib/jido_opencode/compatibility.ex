defmodule Jido.OpenCode.Compatibility do
  @moduledoc """
  Runtime compatibility checks for OpenCode HTTP server.
  """

  alias Jido.OpenCode.{Client, Error}

  @default_port 4096
  @default_host "localhost"

  @doc "Returns compatibility metadata for the OpenCode HTTP server."
  @spec status(keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def status(opts \\ []) when is_list(opts) do
    host = Keyword.get(opts, :host, @default_host)
    port = Keyword.get(opts, :port, @default_port)

    if Client.server_running?(opts) do
      {:ok,
       %{
         host: host,
         port: port,
         server: :running,
         version: "unknown"
       }}
    else
      {:error,
       Error.config_error("OpenCode server is not running", %{
         key: :opencode_server_unavailable,
         details: "Ensure opencode server is running on port #{port}"
       })}
    end
  end

  @doc "Returns `:ok` if compatible, otherwise a structured config error."
  @spec check(keyword()) :: :ok | {:error, Exception.t()}
  def check(opts \\ []) when is_list(opts) do
    case status(opts) do
      {:ok, _metadata} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @doc "Boolean predicate for compatibility checks."
  @spec compatible?(keyword()) :: boolean()
  def compatible?(opts \\ []) when is_list(opts) do
    Client.server_running?(opts)
  end

  @doc "Raises when OpenCode server is incompatible."
  @spec assert_compatible!(keyword()) :: :ok | no_return()
  def assert_compatible!(opts \\ []) when is_list(opts) do
    case check(opts) do
      :ok -> :ok
      {:error, error} -> raise error
    end
  end

  @doc "Returns true when an OpenCode CLI binary can be resolved."
  @spec cli_installed?(keyword()) :: boolean()
  def cli_installed?(opts \\ []) when is_list(opts) do
    # Keep for backward compatibility
    match?({:ok, _}, Jido.OpenCode.CLI.resolve(opts))
  end

  @doc "Returns true when OpenCode server is running on port 4096."
  @spec server_running?(keyword()) :: boolean()
  def server_running?(opts \\ []) when is_list(opts) do
    Client.server_running?(opts)
  end

  defp cli_module do
    Application.get_env(:jido_opencode, :cli_module, Jido.OpenCode.CLI)
  end

  defp command_module do
    Application.get_env(:jido_opencode, :command_module, Jido.OpenCode.SystemCommand)
  end
end
