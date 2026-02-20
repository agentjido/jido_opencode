defmodule JidoOpenCode.ErrorTest do
  @moduledoc """
  Tests for the JidoOpenCode.Error module.
  """

  use ExUnit.Case

  describe "validation_error/2" do
    test "creates InvalidInputError with message" do
      error = JidoOpenCode.Error.validation_error("Invalid input")
      assert error.message == "Invalid input"
    end

    test "creates InvalidInputError with details map" do
      error = JidoOpenCode.Error.validation_error("Invalid query", %{})
      assert error.message == "Invalid query"
    end
  end

  describe "execution_error/2" do
    test "creates ExecutionFailureError with message" do
      error = JidoOpenCode.Error.execution_error("CLI failed")
      assert error.message == "CLI failed"
    end

    test "creates ExecutionFailureError with details" do
      details = %{"exit_code" => 1, "stderr" => "error"}
      error = JidoOpenCode.Error.execution_error("CLI failed", details)
      assert error.message == "CLI failed"
      assert error.details == details
    end
  end

  describe "error classes" do
    test "Invalid class exists" do
      assert JidoOpenCode.Error.Invalid
    end

    test "Execution class exists" do
      assert JidoOpenCode.Error.Execution
    end

    test "Config class exists" do
      assert JidoOpenCode.Error.Config
    end

    test "Internal class exists" do
      assert JidoOpenCode.Error.Internal
    end
  end
end
