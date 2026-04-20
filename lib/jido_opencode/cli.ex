defmodule Jido.OpenCode.CLI do
  @moduledoc false

  alias Jido.OpenCode.{Error, Options}

  @type cli_spec :: %{required(:program) => String.t()}
  @type resolve_opt :: {:opencode_path, String.t()} | {:cli_path, String.t()}

  @doc false
  @spec configured_path([resolve_opt()]) :: String.t() | nil
  def configured_path(opts \\ []) when is_list(opts) do
    opts[:opencode_path] ||
      opts[:cli_path] ||
      Application.get_env(:jido_opencode, :opencode_path)
  end

  @doc false
  @spec resolve([resolve_opt()]) :: {:ok, cli_spec()} | {:error, :enoent}
  def resolve(opts \\ []) when is_list(opts) do
    case configured_path(opts) do
      path when is_binary(path) and path != "" ->
        if File.regular?(path) do
          {:ok, %{program: path}}
        else
          {:error, :enoent}
        end

      _ ->
        case System.find_executable("opencode") do
          nil -> {:error, :enoent}
          path -> {:ok, %{program: path}}
        end
    end
  end

  @doc false
  @spec run(String.t(), Options.t()) :: {:ok, String.t()} | {:error, term()}
  def run(prompt, %Options{} = options) when is_binary(prompt) do
    with {:ok, spec} <- resolve(resolve_opts(options)),
         {:ok, output} <- run_command(spec.program, build_args(prompt, options), options) do
      {:ok, output}
    else
      {:error, :enoent} ->
        {:error, Error.config_error("OpenCode CLI is not installed", %{key: :opencode_cli_not_found})}

      {:error, %{status: status, output: output}} ->
        {:error, Error.execution_error("OpenCode command failed", %{status: status, output: String.trim(output || "")})}

      {:error, reason} ->
        {:error, Error.execution_error("OpenCode command failed", %{reason: inspect(reason)})}
    end
  end

  defp run_command(program, args, %Options{} = options) do
    command_module().run(
      program,
      args,
      timeout: options.timeout_ms,
      cd: options.cwd,
      env: env_to_list(options.env),
      pty: true
    )
  end

  defp build_args(prompt, %Options{} = options) do
    [
      "run",
      "--model",
      options.model,
      "--format",
      options.format,
      prompt
    ]
  end

  defp env_to_list(env) when is_map(env) do
    Enum.map(env, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp resolve_opts(%Options{} = options) do
    if is_binary(options.opencode_path) and options.opencode_path != "" do
      [opencode_path: options.opencode_path]
    else
      []
    end
  end

  defp command_module do
    Application.get_env(:jido_opencode, :command_module, Jido.OpenCode.SystemCommand)
  end
end
