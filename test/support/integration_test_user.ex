defmodule ExEventBus.IntegrationTestUser do
  @moduledoc """
  Test user schema for integration tests
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {JSON.Encoder, only: [:id, :name, :email, :age, :inserted_at, :updated_at]}
  schema "test_users" do
    field(:name, :string)
    field(:email, :string)
    field(:age, :integer)
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :age])
    |> validate_required([:name, :email])
  end
end
