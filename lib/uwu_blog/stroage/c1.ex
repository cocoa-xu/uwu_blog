defmodule UwUBlog.Stroage.C1 do
  @moduledoc false

  @spec put(Keyword.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def put(config, file, path)
      when is_binary(file) and is_binary(path) do
    case File.read(file) do
      {:ok, data} ->
        put_data(config, data, path)

      {:error, reason} ->
        {:error, "Cannot read file at path `#{file}`: #{inspect(reason)}"}
    end
  end

  @spec put_data(Keyword.t(), binary(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def put_data(config, data, path)
      when is_binary(data) and is_binary(path) do
    req = Req.new(Keyword.take(config, [:base_url, :aws_sigv4]))
    bucket = config[:bucket]
    url = Path.join(["/", bucket, path])

    with %Req.Response{status: 200} <- Req.put!(req, url: url, body: data) do
      {:ok, "#{config[:public_url]}#{url}"}
    else
      %Req.Response{status: status, body: body} ->
        {:error, "Failed to put file at `#{url}`: status=#{status}, body=#{body}"}
    end
  end
end
