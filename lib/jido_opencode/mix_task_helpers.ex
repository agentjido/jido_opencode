defmodule Jido.OpenCode.MixTaskHelpers do
  @moduledoc false

  @doc false
  @spec validate_options!([{atom(), term()}]) :: :ok | no_return()
  def validate_options!([]), do: :ok

  def validate_options!(invalid) when is_list(invalid) do
    invalid_text =
      Enum.map_join(invalid, ", ", fn
        {name, nil} -> "--#{normalize_option_name(name)}"
        {name, value} -> "--#{normalize_option_name(name)}=#{value}"
      end)

    Mix.raise("invalid options: #{invalid_text}")
  end

  defp normalize_option_name(name) do
    name
    |> to_string()
    |> String.trim_leading("-")
  end
end
