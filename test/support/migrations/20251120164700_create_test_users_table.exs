defmodule ExEventBus.Repo.Migrations.CreateTestUsersTable do
  use Ecto.Migration

  def change do
    create table(:test_users) do
      add(:name, :string)
      add(:email, :string)
      add(:age, :integer)

      timestamps()
    end
  end
end
