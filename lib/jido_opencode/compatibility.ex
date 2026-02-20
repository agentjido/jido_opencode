defmodule Jido.OpenCode.Compatibility do
  @moduledoc """
  Runtime compatibility checks for local OpenCode CLI features.
  """

  alias Jido.OpenCode.Error

  @command_timeout 5_000
  @required_help_tokens ["run"]
  @required_run_help_tokens ["--format", "json"]

  @doc "Returns compatibility metadata for the current OpenCode CLI."
  @spec status(keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def status(opts \\ []) when is_list(opts) do
    with {:ok, spec} <- resolve_cli(opts),
         {:ok, help_output} <- read_help(spec.program, ["--help"], :opencode_help),
         :ok <- ensure_tokens(help_output, @required_help_tokens, :opencode_help),
         {:ok, run_help_output} <- read_help(spec.program, ["run", "--help"], :opencode_run_help),
         :ok <- ensure_tokens(run_help_output, @required_run_help_tokens, :opencode_run_help) do
      {:ok,
       %{
         program: spec.program,
         version: read_version(spec.program),
         required_tokens: %{
           opencode_help: @required_help_tokens,
           opencode_run_help: @required_run_help_tokens
         }
       }}
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
    match?({:ok, _}, status(opts))
  end

  @doc "Raises when current OpenCode CLI is incompatible."
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
    match?({:ok, _}, resolve_cli(opts))
  end

  defp resolve_cli(opts) do
    case cli_module().resolve(opts) do
      {:ok, spec} ->
        {:ok, spec}

      {:error, reason} ->
        {:error, Error.config_error("OpenCode CLI is not available", %{key: :opencode_cli_not_found, details: reason})}
    end
  end

  defp read_help(program, args, probe_key) do
    case command_module().run(program, args, timeout: @command_timeout) do
      {:ok, output} ->
        {:ok, output}

      {:error, reason} ->
        {:error,
         Error.config_error("Unable to read OpenCode CLI help output", %{key: probe_key, details: inspect(reason)})}
    end
  end

  defp ensure_tokens(help_output, tokens, probe_key) do
    missing = Enum.reject(tokens, &String.contains?(help_output, &1))

    case missing do
      [] ->
        :ok

      _ ->
        {:error,
         Error.config_error("OpenCode CLI is incompatible with JSON run mode", %{
           key: probe_key,
           details: %{missing_tokens: missing}
         })}
    end
  end

  defp read_version(program) do
    case command_module().run(program, ["--version"], timeout: @command_timeout) do
      {:ok, version} -> String.trim(version)
      {:error, _reason} -> "unknown"
    end
  end

  defp cli_module do
    Application.get_env(:jido_opencode, :cli_module, Jido.OpenCode.CLI)
  end

  defp command_module do
    Application.get_env(:jido_opencode, :command_module, Jido.OpenCode.SystemCommand)
  end
end
