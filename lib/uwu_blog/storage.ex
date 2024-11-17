defmodule UwUBlog.Storage do
  @moduledoc false

  def available? do
    get_provider() != nil
  end

  def get_provider do
    Application.get_env(:uwu_blog, __MODULE__)[:provider]
  end

  def put(file, path) do
    case get_provider() do
      {provider, config} ->
        provider.put(config, file, path)

      _ ->
        {:error, "No storage provider configured"}
    end
  end
end
