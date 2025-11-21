defmodule ExEventBus.Repo.Migrations.CreateTestUserPermissionsTable do
  use Ecto.Migration

  def change do
    create table(:test_user_permissions, primary_key: false) do
      add(:user_id, :integer, primary_key: true, null: false)
      add(:resource_id, :integer, primary_key: true, null: false)
      add(:permission_level, :string, null: false)
    end
  end
end
