defmodule Jido.OpenCode.Adapter do
  @moduledoc """
  `Jido.Harness.Adapter` implementation for OpenCode CLI.
  """

  @behaviour Jido.Harness.Adapter

  alias Jido.Harness.{Capabilities, Event, RunRequest, RuntimeContract}
  alias Jido.OpenCode.{CLI, Compatibility, Error, Mapper, Options}

  @impl true
  @spec id() :: atom()
  def id, do: :opencode

  @impl true
  @spec capabilities() :: map()
  def capabilities do
    %Capabilities{
      streaming?: false,
      tool_calls?: false,
      tool_results?: false,
      thinking?: false,
      cancellation?: false
    }
  end

  @impl true
  @spec run(RunRequest.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  def run(%RunRequest{} = request, opts \\ []) when is_list(opts) do
    compat_opts = compatibility_opts(request, opts)

    with :ok <- compatibility_module().check(compat_opts),
         {:ok, options} <- options_module().from_run_request(request, opts),
         {:ok, output} <- cli_module().run(request.prompt, options),
         {:ok, raw_events} <- decode_output(output),
         {:ok, events} <- map_output(raw_events, output, options) do
      {:ok, events}
    else
      {:error, _} = error ->
        error
    end
  rescue
    e in [ArgumentError] ->
      {:error, Error.validation_error("Invalid OpenCode run request", %{details: Exception.message(e)})}
  end

  @impl true
  @spec runtime_contract() :: RuntimeContract.t()
  def runtime_contract do
    RuntimeContract.new!(%{
      provider: :opencode,
      host_env_required_any: ["ZAI_API_KEY"],
      host_env_required_all: [],
      sprite_env_forward: ["ZAI_API_KEY", "ZAI_BASE_URL", "OPENCODE_MODEL", "GH_TOKEN", "GITHUB_TOKEN"],
      sprite_env_injected: %{
        "GH_PROMPT_DISABLED" => "1",
        "GIT_TERMINAL_PROMPT" => "0",
        "ZAI_BASE_URL" => "https://api.z.ai/api/anthropic",
        "OPENCODE_MODEL" => "zai-coding-plan/glm-4.5-air"
      },
      runtime_tools_required: ["opencode"],
      compatibility_probes: [
        %{
          "name" => "opencode_help_run",
          "command" => "opencode --help",
          "expect_all" => ["run"]
        },
        %{
          "name" => "opencode_run_help_json",
          "command" => "opencode run --help",
          "expect_all" => ["--format", "json"]
        }
      ],
      install_steps: [
        %{
          "tool" => "opencode",
          "when_missing" => true,
          "command" =>
            "if command -v npm >/dev/null 2>&1; then npm install -g opencode-ai; else echo 'npm not available'; exit 1; fi"
        }
      ],
      auth_bootstrap_steps: [
        "opencode models zai-coding-plan 2>&1 | grep -q 'zai-coding-plan/'"
      ],
      triage_command_template:
        "if command -v timeout >/dev/null 2>&1; then timeout 120 opencode run --model ${OPENCODE_MODEL:-zai-coding-plan/glm-4.5-air} --format json \"$(cat {{prompt_file}})\"; else opencode run --model ${OPENCODE_MODEL:-zai-coding-plan/glm-4.5-air} --format json \"$(cat {{prompt_file}})\"; fi",
      coding_command_template:
        "if command -v timeout >/dev/null 2>&1; then timeout 180 opencode run --model ${OPENCODE_MODEL:-zai-coding-plan/glm-4.5-air} --format json \"$(cat {{prompt_file}})\"; else opencode run --model ${OPENCODE_MODEL:-zai-coding-plan/glm-4.5-air} --format json \"$(cat {{prompt_file}})\"; fi",
      success_markers: [
        %{"type" => "result", "subtype" => "success"},
        %{"status" => "success"}
      ]
    })
  end

  defp compatibility_opts(%RunRequest{} = request, opts) do
    metadata = if is_map(request.metadata), do: request.metadata, else: %{}
    metadata_opencode = Map.get(metadata, "opencode", Map.get(metadata, :opencode, %{}))

    case map_get(metadata_opencode, :opencode_path) || map_get(metadata_opencode, :cli_path) ||
           Keyword.get(opts, :opencode_path) || Keyword.get(opts, :cli_path) do
      path when is_binary(path) and path != "" -> [opencode_path: path]
      _ -> []
    end
  end

  defp decode_output(output) when is_binary(output) do
    trimmed = String.trim(output)

    cond do
      trimmed == "" ->
        {:ok, []}

      true ->
        decode_json_or_jsonl(trimmed)
    end
  end

  defp decode_output(output) do
    {:error, Error.execution_error("OpenCode returned non-string output", %{output: inspect(output)})}
  end

  defp decode_json_or_jsonl(content) do
    case Jason.decode(content) do
      {:ok, map} when is_map(map) ->
        {:ok, [map]}

      {:ok, list} when is_list(list) ->
        if Enum.all?(list, &is_map/1) do
          {:ok, list}
        else
          {:error, Error.validation_error("OpenCode JSON array output must contain objects only")}
        end

      _ ->
        decode_jsonl_lines(content)
    end
  end

  defp decode_jsonl_lines(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {line, line_number}, {:ok, acc} ->
      case Jason.decode(line) do
        {:ok, map} when is_map(map) ->
          {:cont, {:ok, [map | acc]}}

        {:ok, value} ->
          {:halt,
           {:error,
            Error.validation_error("OpenCode JSON line must be an object", %{
              line: line_number,
              value: inspect(value)
            })}}

        {:error, decode_error} ->
          {:halt,
           {:error,
            Error.validation_error("Invalid JSON output from OpenCode", %{
              line: line_number,
              details: Exception.message(decode_error)
            })}}
      end
    end)
    |> case do
      {:ok, events} -> {:ok, Enum.reverse(events)}
      other -> other
    end
  end

  defp map_output(raw_events, output, options) do
    events =
      raw_events
      |> Enum.flat_map(fn raw ->
        case mapper_module().map_event(raw) do
          {:ok, mapped_events} when is_list(mapped_events) ->
            mapped_events

          {:error, reason} ->
            [mapper_error_event(reason)]
        end
      end)
      |> ensure_session_started(options)
      |> ensure_terminal_event(output)

    {:ok, events}
  end

  defp ensure_session_started(events, %Options{} = options) do
    if Enum.any?(events, &(&1.type == :session_started)) do
      events
    else
      [new_event(:session_started, %{"cwd" => options.cwd}, nil, nil) | events]
    end
  end

  defp ensure_terminal_event(events, output) do
    terminal? = Enum.any?(events, &(&1.type in [:session_completed, :session_failed]))
    has_output? = Enum.any?(events, &(&1.type in [:output_text_delta, :output_text_final]))

    cond do
      terminal? ->
        events

      has_output? ->
        events ++ [new_event(:session_completed, %{"status" => "success"}, extract_session_id(events), nil)]

      String.trim(output) == "" ->
        events ++ [new_event(:session_completed, %{"status" => "success"}, extract_session_id(events), nil)]

      true ->
        events ++
          [
            new_event(:output_text_final, %{"text" => String.trim(output)}, extract_session_id(events), nil),
            new_event(:session_completed, %{"status" => "success"}, extract_session_id(events), nil)
          ]
    end
  end

  defp extract_session_id([%Event{session_id: session_id} | _]) when is_binary(session_id), do: session_id
  defp extract_session_id([_ | rest]), do: extract_session_id(rest)
  defp extract_session_id([]), do: nil

  defp mapper_error_event(reason) do
    new_event(:session_failed, %{"error" => inspect(reason)}, nil, reason)
  end

  defp new_event(type, payload, session_id, raw) do
    Event.new!(%{
      type: type,
      provider: :opencode,
      session_id: session_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      payload: payload,
      raw: raw
    })
  end

  defp map_get(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end

  defp compatibility_module do
    Application.get_env(:jido_opencode, :compatibility_module, Compatibility)
  end

  defp cli_module do
    Application.get_env(:jido_opencode, :cli_module, CLI)
  end

  defp mapper_module do
    Application.get_env(:jido_opencode, :mapper_module, Mapper)
  end

  defp options_module do
    Application.get_env(:jido_opencode, :options_module, Options)
  end
end
