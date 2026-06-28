defmodule UwUBlog.Secret do
  @moduledoc """
  Wraps a sensitive string so it cannot leak through `inspect/1`, log messages,
  crash reports, or Sentry events.

  The value is only obtainable via `reveal/1`, which should be called at the
  last possible moment (e.g. when building an outbound HTTP request body).
  There is deliberately no `String.Chars` implementation, so accidental string
  interpolation (`"\#{secret}"`) raises instead of leaking.
  """

  @enforce_keys [:value]
  defstruct [:value]

  @opaque t :: %__MODULE__{value: String.t()}

  @doc """
  Wraps a secret string. Returns `nil` for blank/unset input so callers can
  treat "unconfigured" uniformly and fail closed.
  """
  @spec new(String.t() | nil) :: t() | nil
  def new(value) when value in [nil, ""], do: nil
  def new(value) when is_binary(value), do: %__MODULE__{value: value}

  @doc """
  Returns the wrapped secret string, or `nil` when unset. Also accepts a bare
  string so config that wasn't routed through `new/1` (e.g. compile-time test
  config) still works.
  """
  @spec reveal(t() | String.t() | nil) :: String.t() | nil
  def reveal(%__MODULE__{value: value}), do: value
  def reveal(value) when is_binary(value), do: value
  def reveal(nil), do: nil

  defimpl Inspect do
    def inspect(_secret, _opts), do: "#UwUBlog.Secret<[REDACTED]>"
  end
end
