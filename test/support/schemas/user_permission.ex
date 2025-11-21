defmodule ExEventBus.Schemas.UserPermission do
  @moduledoc """
  Test schema for composite primary key testing
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ExEventBus.Schemas.User

  @derive {JSON.Encoder, only: [:user_id, :resource_id, :permission_level]}
  @primary_key false
  schema "test_user_permissions" do
    field(:user_id, :integer, primary_key: true)
    field(:resource_id, :integer, primary_key: true)
    field(:permission_level, :string)

    belongs_to(:user, User, define_field: false, foreign_key: :user_id)
  end

  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:user_id, :resource_id, :permission_level])
    |> validate_required([:permission_level])
  end
end
