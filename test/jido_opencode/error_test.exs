defmodule Jido.OpenCode.ErrorTest do
  @moduledoc """
  Tests for the Jido.OpenCode.Error module.
  """

  use ExUnit.Case

  describe "validation_error/2" do
    test "creates InvalidInputError with message" do
      error = Jido.OpenCode.Error.validation_error("Invalid input")
      assert error.message == "Invalid input"
    end

    test "creates InvalidInputError with details map" do
      error = Jido.OpenCode.Error.validation_error("Invalid query", %{})
      assert error.message == "Invalid query"
    end
  end

  describe "execution_error/2" do
    test "creates ExecutionFailureError with message" do
      error = Jido.OpenCode.Error.execution_error("CLI failed")
      assert error.message == "CLI failed"
    end

    test "creates ExecutionFailureError with details" do
      details = %{"exit_code" => 1, "stderr" => "error"}
      error = Jido.OpenCode.Error.execution_error("CLI failed", details)
      assert error.message == "CLI failed"
      assert error.details == details
    end
  end

  describe "error classes" do
    test "Invalid class exists" do
      assert Jido.OpenCode.Error.Invalid
    end

    test "Execution class exists" do
      assert Jido.OpenCode.Error.Execution
    end

    test "Config class exists" do
      assert Jido.OpenCode.Error.Config
    end

    test "Internal class exists" do
      assert Jido.OpenCode.Error.Internal
    end
  end
end
