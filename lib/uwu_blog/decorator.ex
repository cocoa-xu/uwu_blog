defmodule UwUBlog.Tracing.Decorator do
  @moduledoc false

  use Decorator.Define, trace: 0, trace: 1

  def trace(_opts \\ [], body, context) do
    quote location: :keep do
      require OpenTelemetry.Span
      require OpenTelemetry.Tracer

      module = unquote(context.module)
      function = unquote(context.name)

      module_prefix =
        module
        |> Macro.to_string()
        |> String.split(".")
        |> Enum.map(&Macro.underscore/1)
        |> Enum.map_join(".", & &1)

      span_name = Enum.join([module_prefix, function], ".")

      OpenTelemetry.Tracer.with_span span_name do
        span_ctx = OpenTelemetry.Tracer.current_span_ctx()

        try do
          unquote(body)
        rescue
          e ->
            # Gives us a nice error span in HC containing the entire stacktrace
            OpenTelemetry.Span.record_exception(span_ctx, e, __STACKTRACE__, [])
            OpenTelemetry.Span.set_status(span_ctx, OpenTelemetry.status(:error))
            reraise e, __STACKTRACE__
        end
      end
    end
  end
end
