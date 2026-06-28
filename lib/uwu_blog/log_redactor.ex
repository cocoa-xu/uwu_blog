defmodule UwUBlog.LogRedactor do
  @moduledoc """
  A `:logger` primary filter that redacts known secret values from log events
  before any handler (console, Sentry) processes them.

  It is installed at application start (see `UwUBlog.Application`) only when
  secrets are configured, and matches on the secret *value*, so it scrubs the
  secret regardless of which code — ours or a dependency's — emitted it. As a
  primary filter it also covers the Sentry `LoggerHandler` path. Structured and
  crash-report leaks are handled separately by wrapping the secret in
  `UwUBlog.Secret`.
  """

  @replacement "[REDACTED]"

  @doc """
  `:logger` filter callback. `secrets` is the list of raw secret strings to
  redact. Returns the event with any occurrences in the message replaced; never
  drops an event, and never raises.
  """
  @spec filter(:logger.log_event(), [String.t()]) :: :logger.log_event()
  def filter(%{msg: msg} = event, secrets) when is_list(secrets) and secrets != [] do
    %{event | msg: redact_msg(msg, secrets)}
  rescue
    _ -> event
  end

  def filter(event, _secrets), do: event

  defp redact_msg({:string, chardata}, secrets), do: {:string, redact(chardata, secrets)}
  defp redact_msg({:report, report}, secrets), do: {:report, redact_report(report, secrets)}

  defp redact_msg({format, args}, secrets) when is_list(args),
    do: {format, Enum.map(args, &redact_value(&1, secrets))}

  defp redact_msg(other, _secrets), do: other

  defp redact_report(report, secrets) when is_map(report) do
    Map.new(report, fn {key, value} -> {key, redact_value(value, secrets)} end)
  end

  defp redact_report(report, secrets) when is_list(report) do
    Enum.map(report, fn
      {key, value} -> {key, redact_value(value, secrets)}
      value -> redact_value(value, secrets)
    end)
  end

  defp redact_report(report, _secrets), do: report

  defp redact_value(value, secrets) when is_binary(value), do: redact(value, secrets)
  defp redact_value(value, _secrets), do: value

  defp redact(chardata, secrets) do
    string = IO.chardata_to_string(chardata)

    if String.contains?(string, secrets) do
      Enum.reduce(secrets, string, &String.replace(&2, &1, @replacement))
    else
      chardata
    end
  end
end
