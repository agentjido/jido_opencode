defmodule Jido.OpenCode do
  @moduledoc """
  OpenCode CLI integration for the Jido Agent framework.

  Jido.OpenCode provides integration with the OpenCode CLI tool for code analysis and manipulation.

  ## Overview

  This package serves as a bridge to the OpenCode CLI, enabling programmatic execution of code
  analysis, retrieval, and manipulation tasks within Jido-based agent workflows.

  ## Usage

  ### Basic Query

      {:ok, result} = Jido.OpenCode.query("Analyze this codebase for security issues")

  ### Getting Version

      Jido.OpenCode.version()

  ## Features

  - Normalized event stream for OpenCode CLI operations
  - Structured error handling using Splode
  - Schema validation via Zoi
  - Full integration with Jido agent framework

  """

  @doc """
  Returns the version of the Jido.OpenCode library.

  ## Returns

    * A string representing the current version

  ## Example

      iex> Jido.OpenCode.version()
      "0.1.0"

  """
  @spec version() :: String.t()
  def version, do: "0.1.0"

  @doc """
  Execute a query against the OpenCode CLI.

  Sends a query string to the OpenCode CLI and returns the normalized result.

  ## Parameters

    * `query` - A non-empty string containing the query to execute

  ## Returns

    * `{:ok, result}` - On success with the result as a map
    * `{:error, reason}` - On failure with error details

  ## Example

      iex> Jido.OpenCode.query("Analyze this codebase")
      {:ok, %{"query" => "Analyze this codebase", "status" => "placeholder"}}

  """
  @spec query(String.t()) :: {:ok, term()} | {:error, term()}
  def query(query) when is_binary(query) do
    {:ok, %{"query" => query, "status" => "placeholder"}}
  end
end
