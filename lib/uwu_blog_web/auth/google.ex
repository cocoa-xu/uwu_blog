defmodule UwUBlogWeb.Auth.Google do
  @moduledoc """
  "Sign in with Google" via the OAuth 2.0 authorization-code flow (Phase 2).

  Hand-rolled on `Req` — no extra dependencies. The flow:

    1. `authorize_url/1` builds the Google consent URL for a CSRF `state`.
    2. Google redirects back to the callback with a one-time `code`.
    3. `fetch_email/1` exchanges the code for a token and reads the verified
       email from Google's userinfo endpoint.
    4. `allowed?/1` checks that email against the configured allow-list.

  Only `fetch_email/1` ever touches the client secret, and it reveals it solely
  to build the token-exchange request body (see [[UwUBlog.Secret]]).
  """

  use UwUBlogWeb, :verified_routes

  alias UwUBlog.Secret

  @auth_endpoint "https://accounts.google.com/o/oauth2/v2/auth"
  @token_endpoint "https://oauth2.googleapis.com/token"
  @userinfo_endpoint "https://openidconnect.googleapis.com/v1/userinfo"
  @scope "openid email"

  @doc "Whether Google sign-in is configured (client id + secret present)."
  def configured? do
    client_id() not in [nil, ""] and reveal_secret() not in [nil, ""]
  end

  @doc "The Google consent URL for the given CSRF `state`."
  def authorize_url(state) do
    query =
      URI.encode_query(%{
        "client_id" => client_id(),
        "redirect_uri" => redirect_uri(),
        "response_type" => "code",
        "scope" => @scope,
        "state" => state,
        "access_type" => "online",
        "prompt" => "select_account"
      })

    @auth_endpoint <> "?" <> query
  end

  @doc """
  Exchanges an authorization `code` for the signed-in user's verified email.
  Returns `{:ok, email}`, or `{:error, reason}` on any failure.
  """
  def fetch_email(code) when is_binary(code) do
    with {:ok, token} <- exchange_code(code),
         {:ok, info} <- fetch_userinfo(token) do
      case info do
        %{"email" => email, "email_verified" => true} when is_binary(email) -> {:ok, email}
        %{"email" => _email} -> {:error, :email_unverified}
        _ -> {:error, :no_email}
      end
    end
  end

  @doc "Whether `email` is in the configured admin allow-list (case-insensitive)."
  def allowed?(email) when is_binary(email) do
    normalized = email |> String.trim() |> String.downcase()
    normalized != "" and normalized in allowed_emails()
  end

  def allowed?(_email), do: false

  defp exchange_code(code) do
    options =
      [
        form: [
          code: code,
          client_id: client_id(),
          client_secret: reveal_secret(),
          redirect_uri: redirect_uri(),
          grant_type: "authorization_code"
        ],
        retry: false
      ] ++ req_options()

    case Req.post(@token_endpoint, options) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} when is_binary(token) ->
        {:ok, token}

      {:ok, %{status: status}} ->
        {:error, {:token_exchange, status}}

      {:error, reason} ->
        {:error, {:http, reason}}
    end
  end

  defp fetch_userinfo(token) do
    options = [auth: {:bearer, token}, retry: false] ++ req_options()

    case Req.get(@userinfo_endpoint, options) do
      {:ok, %{status: 200, body: %{} = info}} -> {:ok, info}
      {:ok, %{status: status}} -> {:error, {:userinfo, status}}
      {:error, reason} -> {:error, {:http, reason}}
    end
  end

  defp redirect_uri, do: url(~p"/auth/google/callback")

  defp client_id, do: config(:client_id)

  defp reveal_secret, do: Secret.reveal(config(:client_secret))

  defp allowed_emails do
    config(:allowed_emails, "")
    |> String.split(",", trim: true)
    |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
    |> Enum.reject(&(&1 == ""))
  end

  defp req_options, do: config(:req_options, [])

  defp config(key, default \\ nil) do
    case Application.get_env(:uwu_blog, __MODULE__, [])[key] do
      nil -> default
      value -> value
    end
  end
end
