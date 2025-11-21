defmodule ExEventBus.Schemas.Post do
  @moduledoc """
  Test post schema for association testing
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ExEventBus.Schemas.User

  @derive {JSON.Encoder, only: [:id, :title, :body, :user_id, :inserted_at, :updated_at]}
  schema "test_posts" do
    field(:title, :string)
    field(:body, :string)

    belongs_to(:user, User)

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body])
    |> validate_required([:title])
  end
end
