defmodule ExEventBus.Schemas.User do
  @moduledoc """
  Test user schema for integration tests
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ExEventBus.Schemas.{Post, Profile}

  @derive {JSON.Encoder, only: [:id, :name, :email, :age, :inserted_at, :updated_at]}
  schema "test_users" do
    field(:name, :string)
    field(:email, :string)
    field(:age, :integer)

    has_one(:profile, Profile)
    has_many(:posts, Post)

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :age])
    |> validate_required([:name, :email])
    |> cast_assoc(:profile)
    |> cast_assoc(:posts)
  end
end
