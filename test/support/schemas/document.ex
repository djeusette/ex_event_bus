defmodule ExEventBus.Schemas.Document do
  @moduledoc """
  Standalone schema for testing embeds_one without DB
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ExEventBus.Schemas.Picture

  embedded_schema do
    field(:title, :string)
    field(:content, :string)

    embeds_one(:picture, Picture, on_replace: :update)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [:title, :content])
    |> cast_embed(:picture)
    |> validate_required([:title])
  end
end
