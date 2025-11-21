defmodule ExEventBus.Repo.Migrations.CreateTestPostsTable do
  use Ecto.Migration

  def change do
    create table(:test_posts) do
      add(:title, :string)
      add(:body, :string)
      add(:user_id, references(:test_users, on_delete: :delete_all))

      timestamps()
    end

    create(index(:test_posts, [:user_id]))
  end
end
