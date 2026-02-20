defmodule JidoOpenCodeTest do
  @moduledoc """
  Tests for the JidoOpenCode module.
  """

  use ExUnit.Case
  doctest JidoOpenCode

  describe "query/1" do
    test "returns ok tuple with result map" do
      assert {:ok, result} = JidoOpenCode.query("test query")
      assert is_map(result)
      assert result["query"] == "test query"
      assert result["status"] == "placeholder"
    end

    test "returns ok tuple for various query strings" do
      queries = [
        "Analyze this codebase",
        "What are the security issues?",
        "Show me the API surface"
      ]

      Enum.each(queries, fn query ->
        assert {:ok, result} = JidoOpenCode.query(query)
        assert result["query"] == query
      end)
    end
  end

  describe "version/0" do
    test "returns version string" do
      version = JidoOpenCode.version()
      assert is_binary(version)
      assert version == "0.1.0"
    end

    test "version format is valid" do
      version = JidoOpenCode.version()
      assert String.match?(version, ~r/^\d+\.\d+\.\d+$/)
    end
  end
end
