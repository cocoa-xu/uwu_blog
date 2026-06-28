defmodule UwUBlog.Secrets do
  @moduledoc """
  Central list of sensitive values that must be scrubbed from logs.

  Used to install the log redaction filter at application start (see
  `UwUBlog.LogRedactor`). Add new secret sources here as they appear.
  """

  alias UwUBlog.Secret

  @doc "All currently-configured secret strings, with blanks removed."
  @spec values() :: [String.t()]
  def values do
    [google_client_secret()]
    |> Enum.flat_map(&normalize/1)
    |> Enum.uniq()
  end

  defp google_client_secret do
    :uwu_blog
    |> Application.get_env(UwUBlogWeb.Auth.Google, [])
    |> Keyword.get(:client_secret)
  end

  defp normalize(%Secret{} = secret), do: List.wrap(Secret.reveal(secret))
  defp normalize(value) when is_binary(value) and value != "", do: [value]
  defp normalize(_other), do: []
end
