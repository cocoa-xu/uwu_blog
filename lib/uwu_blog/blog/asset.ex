defmodule UwUBlog.Blog.Asset do
  use Ecto.Schema

  import Ecto.Changeset

  alias UwUBlog.Repo

  @primary_key {:id, :id, autogenerate: true}
  schema "assets" do
    field :type, Ecto.Enum, values: [:image, :file]
    field :key, :string
    field :public_url, :string
    field :mtime, :utc_datetime_usec
    field :checksum, :string

    timestamps()
  end

  def changeset(asset, params \\ %{}) do
    fields = [:type, :key, :public_url, :mtime, :checksum]

    asset
    |> cast(params, fields)
    |> validate_required(fields)
    |> unique_constraint(:key)
  end

  def get_asset(key) when is_binary(key) do
    Repo.get_by(__MODULE__, key: key)
  end

  defp mtime_to_datetime({{year, month, day}, {hour, minute, second}}) do
    DateTime.new!(
      Date.new!(year, month, day),
      Time.new!(hour, minute, second)
    )
    |> DateTime.add(0, :microsecond, Calendar.UTCOnlyTimeZoneDatabase)
  end

  def file_updated?(path, key) do
    mtime = mtime_to_datetime(File.stat!(path).mtime)

    if asset = get_asset(key) do
      if asset.mtime != mtime do
        checksum = checksum(path)

        {:ok,
         %{
           updated?: asset.checksum != checksum,
           asset: asset,
           public_url: asset.public_url,
           mtime: mtime,
           checksum: checksum
         }}
      else
        {:ok,
         %{
           updated?: false,
           asset: asset,
           public_url: asset.public_url,
           mtime: mtime,
           checksum: asset.checksum
         }}
      end
    else
      {:ok,
       %{updated?: true, asset: nil, public_url: nil, mtime: mtime, checksum: checksum(path)}}
    end
  rescue
    _ ->
      {:error, "Cannot read file at `#{path}`"}
  end

  defp checksum(filepath) do
    :crypto.hash(:sha256, File.read!(filepath))
    |> Base.encode16(case: :lower)
  end
end
