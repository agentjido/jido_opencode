defmodule Jido.OpenCode.Error do
  @moduledoc """
  Centralized error handling for Jido.OpenCode using Splode.

  Error classes are for classification; concrete error structs are for raising/matching.

  ## Error Classification

  Errors are organized into four categories:
  - `:invalid` - Invalid input or configuration parameters
  - `:execution` - Runtime execution failures (e.g., CLI failures, timeouts)
  - `:config` - Configuration issues
  - `:internal` - Internal system errors

  ## Helper Functions

  Use the provided helpers for consistent error creation:
  - `validation_error/2` - Create validation errors with details
  - `execution_error/2` - Create execution failure errors

  ## Example

      case Jido.OpenCode.query(input) do
        {:error, error} -> handle_error(error)
        {:ok, result} -> {:ok, result}
      end

  """

  use Splode,
    error_classes: [
      invalid: Invalid,
      execution: Execution,
      config: Config,
      internal: Internal
    ],
    unknown_error: __MODULE__.Internal.UnknownError

  # Error classes – classification only
  defmodule Invalid do
    @moduledoc "Invalid input error class for Splode."
    use Splode.ErrorClass, class: :invalid
  end

  defmodule Execution do
    @moduledoc "Execution error class for Splode."
    use Splode.ErrorClass, class: :execution
  end

  defmodule Config do
    @moduledoc "Configuration error class for Splode."
    use Splode.ErrorClass, class: :config
  end

  defmodule Internal do
    @moduledoc "Internal error class for Splode."
    use Splode.ErrorClass, class: :internal

    defmodule UnknownError do
      @moduledoc false
      defexception [:message, :details]
    end
  end

  # Concrete exception structs – raise/rescue these
  defmodule InvalidInputError do
    @moduledoc """
    Error for invalid input parameters.

    Fields:
    - `message` - Human-readable error message
    - `field` - The field that caused the error (optional)
    - `value` - The problematic value (optional)
    - `details` - Additional error context (optional)
    """
    defexception [:message, :field, :value, :details]
  end

  defmodule ExecutionFailureError do
    @moduledoc """
    Error for runtime execution failures.

    Fields:
    - `message` - Human-readable error message
    - `details` - Additional error context and diagnostics
    """
    defexception [:message, :details]
  end

  # Helper functions

  @doc """
  Create a validation error with detailed context.

  ## Parameters

    * `message` - Error message
    * `details` - Map of additional error details (default: `%{}`)

  ## Returns

    * An `InvalidInputError` exception struct

  """
  @spec validation_error(String.t(), map()) :: %InvalidInputError{}
  def validation_error(message, details \\ %{}) do
    opts = [message: message] ++ Enum.to_list(details)
    InvalidInputError.exception(opts)
  end

  @doc """
  Create an execution failure error with diagnostic details.

  ## Parameters

    * `message` - Error message describing the failure
    * `details` - Map of diagnostic information (default: `%{}`)

  ## Returns

    * An `ExecutionFailureError` exception struct

  """
  @spec execution_error(String.t(), map()) :: %ExecutionFailureError{}
  def execution_error(message, details \\ %{}) do
    ExecutionFailureError.exception(message: message, details: details)
  end
end
