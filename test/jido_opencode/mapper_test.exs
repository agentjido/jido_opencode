defmodule Jido.OpenCode.MapperTest do
  use ExUnit.Case, async: true

  alias Jido.OpenCode.Mapper

  test "maps assistant events to output_text_delta" do
    assert {:ok, events} =
             Mapper.map_event(%{
               "type" => "assistant",
               "session_id" => "oc-1",
               "text" => "Hello"
             })

    assert Enum.map(events, & &1.type) == [:output_text_delta]
    assert hd(events).payload["text"] == "Hello"
  end

  test "maps success result events to completion" do
    assert {:ok, events} =
             Mapper.map_event(%{
               "type" => "result",
               "status" => "success",
               "result" => "Done"
             })

    assert Enum.any?(events, &(&1.type == :session_completed))
  end

  test "maps error status to session_failed" do
    assert {:ok, events} =
             Mapper.map_event(%{
               "type" => "result",
               "status" => "error",
               "error" => "boom"
             })

    assert Enum.any?(events, &(&1.type == :session_failed))
  end

  test "returns validation errors for non-map input" do
    assert {:error, %Jido.OpenCode.Error.InvalidInputError{}} = Mapper.map_event("bad")
  end
end
