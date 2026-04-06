defmodule Jido.OpenCode.EventTranslator do
  @moduledoc """
  Translates OpenCode SSE events into Jido.Harness.Event structs.

  Handles the conversion from streaming SSE format (similar to OpenAI)
  to the normalized Jido.Harness.Event format.
  """

  alias Jido.Harness.Event

  @doc """
  Translates a raw SSE event map into Jido.Harness.Event structs.

  Returns a list of events as a single SSE chunk may contain multiple
  logical events (text delta, tool call, usage, etc.).
  """
  @spec translate(map(), String.t(), String.t(), String.t()) :: [Event.t()]
  def translate(sse_event, session_id, cwd, model) do
    cond do
      sse_event["done"] == true ->
        [
          Event.new!(%{
            type: :session_completed,
            provider: :opencode,
            session_id: session_id,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            payload: %{"status" => "success"},
            raw: sse_event
          })
        ]

      is_map(sse_event["choices"]) or is_list(sse_event["choices"]) ->
        translate_chat_completion(sse_event, session_id, cwd, model)

      is_map(sse_event["usage"]) ->
        translate_usage(sse_event, session_id, cwd, model)

      is_map(sse_event["error"]) ->
        [
          Event.new!(%{
            type: :session_failed,
            provider: :opencode,
            session_id: session_id,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            payload: %{
              "status" => "error",
              "error" => sse_event["error"]["message"] || "Unknown error"
            },
            raw: sse_event
          })
        ]

      true ->
        []
    end
  end

  defp translate_chat_completion(event, session_id, cwd, model) do
    choices = List.wrap(event["choices"])

    Enum.flat_map(choices, fn choice ->
      events = []

      events =
        if choice["delta"]["content"] do
          events ++
            [
              Event.new!(%{
                type: :output_text_delta,
                provider: :opencode,
                session_id: session_id,
                timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
                payload: %{
                  "text" => choice["delta"]["content"],
                  "cwd" => cwd,
                  "model" => model
                },
                raw: event
              })
            ]
        else
          events
        end

      events =
        if choice["delta"]["tool_calls"] do
          events ++ translate_tool_calls(choice["delta"]["tool_calls"], session_id, event)
        else
          events
        end

      events =
        if choice["finish_reason"] == "stop" or choice["finish_reason"] == "tool_calls" do
          events ++
            [
              Event.new!(%{
                type: :output_text_final,
                provider: :opencode,
                session_id: session_id,
                timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
                payload: %{
                  "cwd" => cwd,
                  "model" => model,
                  "finish_reason" => choice["finish_reason"]
                },
                raw: event
              })
            ]
        else
          events
        end

      events
    end)
  end

  defp translate_tool_calls(tool_calls, session_id, raw_event) when is_list(tool_calls) do
    Enum.flat_map(tool_calls, fn tool_call ->
      [
        Event.new!(%{
          type: :tool_call_delta,
          provider: :opencode,
          session_id: session_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          payload: %{
            "id" => tool_call["id"],
            "name" => get_in(tool_call, ["function", "name"]),
            "arguments" => get_in(tool_call, ["function", "arguments"])
          },
          raw: raw_event
        })
      ]
    end)
  end

  defp translate_usage(event, session_id, _cwd, _model) do
    usage = event["usage"]

    [
      Event.new!(%{
        type: :usage_report,
        provider: :opencode,
        session_id: session_id,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        payload: %{
          "prompt_tokens" => usage["prompt_tokens"],
          "completion_tokens" => usage["completion_tokens"],
          "total_tokens" => usage["total_tokens"]
        },
        raw: event
      })
    ]
  end
end
