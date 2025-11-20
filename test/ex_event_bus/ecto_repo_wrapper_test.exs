defmodule ExEventBus.EctoRepoWrapperTest do
  use ExUnit.Case, async: true

  import ExEventBus.EctoRepoWrapper

  defmodule TestSchema do
    use Ecto.Schema

    schema "test" do
      field(:name, :string)
      field(:email, :string)
      field(:age, :integer)
    end
  end

  describe "get_initial_data/1" do
    test "extracts only changed fields from changeset data" do
      data = %TestSchema{name: "John", email: "old@example.com", age: 30}
      changeset = %Ecto.Changeset{data: data, changes: %{email: "new@example.com"}}

      assert get_initial_data(changeset) == %{email: "old@example.com"}
    end

    test "returns empty map when no changes" do
      data = %TestSchema{name: "John", email: "john@example.com", age: 30}
      changeset = %Ecto.Changeset{data: data, changes: %{}}

      assert get_initial_data(changeset) == %{}
    end

    test "handles multiple changed fields" do
      data = %TestSchema{name: "John", email: "old@example.com", age: 30}

      changeset = %Ecto.Changeset{
        data: data,
        changes: %{email: "new@example.com", age: 35}
      }

      assert get_initial_data(changeset) == %{email: "old@example.com", age: 30}
    end

    test "handles nil values in initial data" do
      data = %TestSchema{name: nil, email: "john@example.com", age: nil}
      changeset = %Ecto.Changeset{data: data, changes: %{name: "John", age: 25}}

      assert get_initial_data(changeset) == %{name: nil, age: nil}
    end

    test "handles fields changed to nil" do
      data = %TestSchema{name: "John", email: "john@example.com", age: 30}
      changeset = %Ecto.Changeset{data: data, changes: %{name: nil}}

      assert get_initial_data(changeset) == %{name: "John"}
    end

    test "handles fields not present in initial data (new insert)" do
      data = %TestSchema{}

      changeset = %Ecto.Changeset{
        data: data,
        changes: %{name: "John", email: "john@example.com", age: 30}
      }

      assert get_initial_data(changeset) == %{name: nil, email: nil, age: nil}
    end
  end
end
