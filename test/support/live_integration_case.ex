defmodule Jido.OpenCode.LiveIntegrationCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Jido.OpenCode.{CLI, Compatibility}

  @env_loaded_key {__MODULE__, :env_loaded}

  using do
    quote do
      import Jido.OpenCode.LiveIntegrationCase

      @moduletag :integration
      @moduletag timeout: 180_000
    end
  end

  def skip_reason do
    ensure_env_loaded()

    missing_auth_reason() ||
      cli_skip_reason() ||
      compatibility_skip_reason()
  end

  setup _tags do
    ensure_env_loaded()

    {:ok,
     prompt: live_prompt(),
     cwd: live_cwd(),
     model: env_value("JIDO_OPENCODE_LIVE_MODEL") || env_value("OPENCODE_MODEL"),
     timeout_ms: env_integer("JIDO_OPENCODE_LIVE_TIMEOUT_MS", 180_000),
     cli_opts: cli_opts(),
     require_success?: truthy?(System.get_env("JIDO_OPENCODE_REQUIRE_SUCCESS"))}
  end

  def live_prompt do
    env_value("JIDO_OPENCODE_LIVE_PROMPT") || "Reply with exactly one word: READY"
  end

  def live_cwd do
    env_value("JIDO_OPENCODE_LIVE_CWD") || File.cwd!()
  end

  def cli_opts do
    case env_value("JIDO_OPENCODE_CLI_PATH") || env_value("OPENCODE_CLI_PATH") do
      nil -> []
      path -> [opencode_path: path]
    end
  end

  defp missing_auth_reason do
    if env_value("ZAI_API_KEY") do
      nil
    else
      "set ZAI_API_KEY to run OpenCode integration tests"
    end
  end

  defp cli_skip_reason do
    case CLI.resolve(cli_opts()) do
      {:ok, _spec} ->
        nil

      {:error, :enoent} ->
        "OpenCode CLI is not available. Install it with `mix opencode.install`."

      {:error, reason} ->
        "OpenCode CLI could not be resolved: #{inspect(reason)}"
    end
  end

  defp compatibility_skip_reason do
    case Compatibility.check(cli_opts()) do
      :ok -> nil
      {:error, reason} -> "OpenCode CLI compatibility check failed: #{reason_message(reason)}"
    end
  end

  defp reason_message(%{__exception__: true} = reason), do: Exception.message(reason)
  defp reason_message(reason), do: inspect(reason)

  defp env_integer(name, default) do
    case env_value(name) do
      nil ->
        default

      value ->
        case Integer.parse(value) do
          {parsed, ""} -> parsed
          _ -> default
        end
    end
  end

  defp env_value(name) do
    case System.get_env(name) do
      value when is_binary(value) ->
        value = String.trim(value)
        if value == "", do: nil, else: value

      _ ->
        nil
    end
  end

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?("1"), do: true
  defp truthy?("yes"), do: true
  defp truthy?(_), do: false

  defp ensure_env_loaded do
    case :persistent_term.get(@env_loaded_key, false) do
      true ->
        :ok

      false ->
        maybe_load_dotenv()
        :persistent_term.put(@env_loaded_key, true)
        :ok
    end
  end

  defp maybe_load_dotenv do
    if File.exists?(".env") do
      ".env"
      |> File.stream!()
      |> Enum.each(&load_env_line/1)
    end
  end

  defp load_env_line(line) do
    line = String.trim(line)

    cond do
      line == "" ->
        :ok

      String.starts_with?(line, "#") ->
        :ok

      true ->
        case Regex.run(~r/^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$/, line) do
          [_, key, raw_value] ->
            if System.get_env(key) in [nil, ""] do
              System.put_env(key, normalize_env_value(raw_value))
            end

          _ ->
            :ok
        end
    end
  end

  defp normalize_env_value(raw_value) do
    value = String.trim(raw_value)

    cond do
      String.starts_with?(value, "\"") and String.ends_with?(value, "\"") ->
        value
        |> String.trim_leading("\"")
        |> String.trim_trailing("\"")

      String.starts_with?(value, "'") and String.ends_with?(value, "'") ->
        value
        |> String.trim_leading("'")
        |> String.trim_trailing("'")

      true ->
        value
    end
  end
end
