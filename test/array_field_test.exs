defmodule ExEventBus.ArrayFieldTest do
  use ExUnit.Case, async: true

  alias ExEventBus.EctoRepoWrapper

  defmodule TestSchema do
    use Ecto.Schema
    import Ecto.Changeset

    schema "test" do
      field(:name, :string)
      field(:private_rooms, {:array, :string}, default: [])
      field(:tags, {:array, :string}, default: [])
      field(:accommodation_ids, {:array, Ecto.UUID}, default: [])
    end

    def changeset(schema, attrs) do
      schema
      |> cast(attrs, [:name, :private_rooms, :tags, :accommodation_ids])
    end
  end

  describe "get_initial_data/1 with array fields" do
    test "handles array field with default [] when not changed" do
      data = %TestSchema{name: "Test", private_rooms: [], tags: []}
      changeset = %Ecto.Changeset{data: data, changes: %{name: "New Name"}}

      assert EctoRepoWrapper.get_initial_data(changeset) == %{name: "Test"}
    end

    test "handles array field with default [] when changed from empty to populated" do
      data = %TestSchema{name: "Test", private_rooms: [], tags: []}

      changeset = %Ecto.Changeset{
        data: data,
        changes: %{private_rooms: ["room1", "room2"]}
      }

      assert EctoRepoWrapper.get_initial_data(changeset) == %{private_rooms: []}
    end

    test "handles array field when changed from populated to different values" do
      data = %TestSchema{name: "Test", private_rooms: ["room1"], tags: ["tag1"]}

      changeset = %Ecto.Changeset{
        data: data,
        changes: %{private_rooms: ["room1", "room2"]}
      }

      assert EctoRepoWrapper.get_initial_data(changeset) == %{private_rooms: ["room1"]}
    end

    test "handles UUID array field with default [] when changed" do
      uuid1 = "550e8400-e29b-41d4-a716-446655440000"
      uuid2 = "550e8400-e29b-41d4-a716-446655440001"
      data = %TestSchema{name: "Test", accommodation_ids: []}

      changeset = %Ecto.Changeset{
        data: data,
        changes: %{accommodation_ids: [uuid1, uuid2]}
      }

      assert EctoRepoWrapper.get_initial_data(changeset) == %{accommodation_ids: []}
    end

    test "handles UUID array field when changing values" do
      uuid1 = "550e8400-e29b-41d4-a716-446655440000"
      uuid2 = "550e8400-e29b-41d4-a716-446655440001"
      uuid3 = "550e8400-e29b-41d4-a716-446655440002"
      data = %TestSchema{name: "Test", accommodation_ids: [uuid1]}

      changeset = %Ecto.Changeset{
        data: data,
        changes: %{accommodation_ids: [uuid1, uuid2, uuid3]}
      }

      assert EctoRepoWrapper.get_initial_data(changeset) == %{accommodation_ids: [uuid1]}
    end
  end

  describe "get_changes/1 with array fields" do
    test "handles array field with default [] when changed" do
      changeset =
        TestSchema.changeset(%TestSchema{}, %{
          name: "Test",
          private_rooms: ["room1", "room2"]
        })

      changes = EctoRepoWrapper.get_changes(changeset)

      assert changes == %{
               name: "Test",
               private_rooms: ["room1", "room2"]
             }
    end
  end
end
