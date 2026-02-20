defmodule Jido.OpenCode.Mapper do
  @moduledoc """
  Maps OpenCode JSON events into normalized `Jido.Harness.Event` structs.
  """

  alias Jido.Harness.Event
  alias Jido.OpenCode.Error

  @doc "Maps one OpenCode JSON event map into one or more normalized harness events."
  @spec map_event(map()) :: {:ok, [Event.t()]} | {:error, term()}
  def map_event(event) when is_map(event) do
    session_id = extract_session_id(event)
    timestamp = extract_timestamp(event)
    type = normalize_type(event)
    text = extract_text(event)

    events =
      []
      |> maybe_add_session_started(type, session_id, timestamp, event)
      |> maybe_add_output(type, text, session_id, timestamp, event)
      |> maybe_add_failure(type, session_id, timestamp, event)
      |> maybe_add_completion(type, text, session_id, timestamp, event)
      |> maybe_add_text_fallback(text, session_id, timestamp, event)

    {:ok, events}
  end

  def map_event(other) do
    {:error, Error.validation_error("OpenCode mapper expects a map event", %{value: inspect(other)})}
  end

  defp maybe_add_session_started(acc, type, session_id, timestamp, raw) do
    if type in ["session_started", "session.start", "session.started", "init"] do
      [
        new_event(
          :session_started,
          session_id,
          timestamp,
          %{"cwd" => map_get(raw, :cwd), "model" => map_get(raw, :model)},
          raw
        )
        | acc
      ]
    else
      acc
    end
  end

  defp maybe_add_output(acc, type, text, session_id, timestamp, raw) do
    cond do
      blank?(text) ->
        acc

      type in ["output_text_final", "text.final", "final"] ->
        [new_event(:output_text_final, session_id, timestamp, %{"text" => text}, raw) | acc]

      type in ["output_text_delta", "assistant", "message", "delta", "text.delta"] ->
        [new_event(:output_text_delta, session_id, timestamp, %{"text" => text}, raw) | acc]

      true ->
        acc
    end
  end

  defp maybe_add_failure(acc, type, session_id, timestamp, raw) do
    if failure_event?(type, raw) do
      payload = %{"error" => extract_error(raw)}
      [new_event(:session_failed, session_id, timestamp, payload, raw) | acc]
    else
      acc
    end
  end

  defp maybe_add_completion(acc, type, text, session_id, timestamp, raw) do
    if success_event?(type, raw) do
      summary =
        %{
          "status" => map_get(raw, :status, "success"),
          "result" => blank_to_nil(text)
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      [new_event(:session_completed, session_id, timestamp, summary, raw) | acc]
    else
      acc
    end
  end

  defp maybe_add_text_fallback([], text, session_id, timestamp, raw) when not is_nil(text) do
    [new_event(:output_text_delta, session_id, timestamp, %{"text" => text}, raw)]
  end

  defp maybe_add_text_fallback(acc, _text, _session_id, _timestamp, _raw), do: acc

  defp success_event?(type, raw) do
    cond do
      type in ["session_completed", "session.complete", "session.completed"] ->
        true

      type == "result" and map_get(raw, :subtype) == "success" ->
        true

      type == "result" and map_get(raw, :is_error) == false ->
        true

      map_get(raw, :status) == "success" ->
        true

      true ->
        false
    end
  end

  defp failure_event?(type, raw) do
    type in ["error", "session_failed", "session.fail", "session.failed"] or
      map_get(raw, :status) == "error" or
      map_get(raw, :is_error) == true
  end

  defp normalize_type(raw) do
    raw
    |> map_get(:type, map_get(raw, :event_type, map_get(raw, :kind, map_get_nested(raw, ["event", "type"], ""))))
    |> to_string()
    |> String.trim()
  end

  defp extract_session_id(raw) do
    raw
    |> map_get(:session_id, map_get(raw, :sessionId, map_get_nested(raw, ["event", "session_id"], nil)))
    |> case do
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end

  defp extract_timestamp(raw) do
    value = map_get(raw, :timestamp, map_get(raw, :time, nil))
    if is_binary(value) and value != "", do: value, else: DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp extract_text(raw) do
    cond do
      is_binary(map_get(raw, :result)) ->
        String.trim(map_get(raw, :result))

      is_binary(map_get(raw, :output_text)) ->
        String.trim(map_get(raw, :output_text))

      is_binary(map_get(raw, :text)) ->
        String.trim(map_get(raw, :text))

      is_binary(map_get(raw, :delta)) ->
        String.trim(map_get(raw, :delta))

      is_binary(map_get(raw, :message)) ->
        String.trim(map_get(raw, :message))

      is_map(map_get(raw, :message)) and is_list(map_get_nested(raw, ["message", "content"], [])) ->
        raw
        |> map_get_nested(["message", "content"], [])
        |> Enum.flat_map(fn
          %{"type" => "text", "text" => text} when is_binary(text) -> [text]
          %{:type => "text", :text => text} when is_binary(text) -> [text]
          _ -> []
        end)
        |> Enum.join("")
        |> String.trim()
        |> blank_to_nil()

      true ->
        nil
    end
  end

  defp extract_error(raw) do
    cond do
      is_binary(map_get(raw, :error)) -> String.trim(map_get(raw, :error))
      is_binary(map_get(raw, :message)) -> String.trim(map_get(raw, :message))
      true -> inspect(raw)
    end
  end

  defp new_event(type, session_id, timestamp, payload, raw) do
    Event.new!(%{
      type: type,
      provider: :opencode,
      session_id: session_id,
      timestamp: timestamp,
      payload: stringify_keys(payload),
      raw: raw
    })
  end

  defp map_get(map, key, default \\ nil)

  defp map_get(map, key, default) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp map_get(map, key, default) when is_map(map) and is_binary(key) do
    Enum.reduce_while(map, default, fn
      {map_key, value}, _acc when is_binary(map_key) and map_key == key ->
        {:halt, value}

      {map_key, value}, acc when is_atom(map_key) ->
        if Atom.to_string(map_key) == key, do: {:halt, value}, else: {:cont, acc}

      _, acc ->
        {:cont, acc}
    end)
  end

  defp map_get_nested(map, [key], default) when is_map(map) do
    map_get(map, key, default)
  end

  defp map_get_nested(map, [head | tail], default) when is_map(map) do
    case map_get(map, head) do
      nested when is_map(nested) -> map_get_nested(nested, tail, default)
      _ -> default
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_atom(key) -> Map.put(acc, Atom.to_string(key), value)
      {key, value}, acc when is_binary(key) -> Map.put(acc, key, value)
      _, acc -> acc
    end)
  end

  defp blank?(value), do: is_nil(blank_to_nil(value))

  defp blank_to_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp blank_to_nil(value), do: value
end
