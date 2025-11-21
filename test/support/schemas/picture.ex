defmodule ExEventBus.Schemas.Picture do
  @moduledoc """
  Embedded schema for testing embeds_one with ID tracking
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field(:url, :string)
  end

  def changeset(picture, attrs) do
    picture
    |> cast(attrs, [:id, :url])
    |> validate_required([:url])
  end
end
