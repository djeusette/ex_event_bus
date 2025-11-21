defmodule ExEventBus.Repo.Migrations.CreateTestProfilesTable do
  use Ecto.Migration

  def change do
    create table(:test_profiles) do
      add(:bio, :string)
      add(:avatar_url, :string)
      add(:user_id, references(:test_users, on_delete: :delete_all))

      timestamps()
    end

    create(index(:test_profiles, [:user_id]))
  end
end
