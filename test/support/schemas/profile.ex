defmodule ExEventBus.Schemas.Profile do
  @moduledoc """
  Test profile schema for association testing
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ExEventBus.Schemas.User

  @derive {JSON.Encoder, only: [:id, :bio, :avatar_url, :user_id, :inserted_at, :updated_at]}
  schema "test_profiles" do
    field(:bio, :string)
    field(:avatar_url, :string)

    belongs_to(:user, User)

    timestamps()
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:bio, :avatar_url])
    |> validate_required([:bio])
  end
end
