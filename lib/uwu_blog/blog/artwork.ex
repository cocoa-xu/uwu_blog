defmodule UwUBlog.Blog.Artwork do
  use Ecto.Schema

  import Ecto.Changeset

  alias UwUBlog.Repo
  alias UwUBlog.Storage

  require Logger

  schema "artworks" do
    field :public_url, :string
    field :checksum, :string

    timestamps()
  end

  def changeset(artwork, params \\ %{}) do
    fields = [:public_url, :checksum]

    artwork
    |> cast(params, fields)
    |> validate_required(fields)
    |> unique_constraint(:checksum)
  end

  def get_artwork(checksum) when is_binary(checksum) do
    Repo.get_by(__MODULE__, checksum: checksum)
  end

  def update_artwork(data, checksum, type)
      when is_binary(data) and is_binary(checksum) and is_binary(type) do
    data = Base.decode64!(data)
    data_checksum = checksum(data)

    if Plug.Crypto.secure_compare(data_checksum, checksum) do
      case upload_artwork(data, checksum, type) do
        {:ok, public_url} ->
          Logger.info("Uploaded artwork, public_url=#{public_url}")

          case Repo.insert(changeset(%__MODULE__{}, %{public_url: public_url, checksum: checksum})) do
            {:ok, artwork} -> {:ok, artwork}
            {:error, _} -> {:ok, Repo.get_by(__MODULE__, checksum: checksum)}
          end

        {:error, reason} ->
          Logger.error("Error uploading artwork: #{reason}")

          {:error, reason}
      end
    else
      Logger.error("Checksum mismatched, expected=[#{checksum}], got=[#{data_checksum}]")
      {:error, "checksum mismatched"}
    end
  rescue
    e ->
      Logger.error("Error decoding base64 data: #{inspect(e)}")
      {:error, "checksum mismatched"}
  end

  def upload_artwork(data, checksum, type) do
    filename = "#{checksum}.#{type}"
    key = "/artworks/#{filename}"

    if Storage.available?() do
      Storage.put_data(data, key)
    else
      {:error, "Storage is not configured!"}
    end
  end

  defp checksum(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :lower)
  end
end
