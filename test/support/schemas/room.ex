defmodule ExEventBus.Schemas.Room do
  @moduledoc """
  Test room schema for testing array fields
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {JSON.Encoder, only: [:id, :name, :private_rooms, :inserted_at, :updated_at]}
  schema "test_rooms" do
    field(:name, :string)
    field(:private_rooms, {:array, :string}, default: [])

    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :private_rooms])
    |> validate_required([:name])
  end
end
