defmodule ExEventBus.EctoRepoWrapperTest do
  use ExUnit.Case, async: true

  alias ExEventBus.EctoRepoWrapper
  alias ExEventBus.Schemas.{Post, Profile, User}

  defmodule TestSchema do
    use Ecto.Schema

    schema "test" do
      field(:name, :string)
      field(:email, :string)
      field(:age, :integer)
    end
  end

  describe "get_initial_data/1 - simple fields" do
    test "extracts only changed fields from changeset data" do
      data = %TestSchema{name: "John", email: "old@example.com", age: 30}
      changeset = %Ecto.Changeset{data: data, changes: %{email: "new@example.com"}}

      assert EctoRepoWrapper.get_initial_data(changeset) == %{email: "old@example.com"}
    end

    test "returns empty map when no changes" do
      data = %TestSchema{name: "John", email: "john@example.com", age: 30}
      changeset = %Ecto.Changeset{data: data, changes: %{}}

      assert EctoRepoWrapper.get_initial_data(changeset) == %{}
    end

    test "handles multiple changed fields" do
      data = %TestSchema{name: "John", email: "old@example.com", age: 30}

      changeset = %Ecto.Changeset{
        data: data,
        changes: %{email: "new@example.com", age: 35}
      }

      assert EctoRepoWrapper.get_initial_data(changeset) == %{email: "old@example.com", age: 30}
    end

    test "handles nil values in initial data" do
      data = %TestSchema{name: nil, email: "john@example.com", age: nil}
      changeset = %Ecto.Changeset{data: data, changes: %{name: "John", age: 25}}

      assert EctoRepoWrapper.get_initial_data(changeset) == %{name: nil, age: nil}
    end

    test "handles fields changed to nil" do
      data = %TestSchema{name: "John", email: "john@example.com", age: 30}
      changeset = %Ecto.Changeset{data: data, changes: %{name: nil}}

      assert EctoRepoWrapper.get_initial_data(changeset) == %{name: "John"}
    end

    test "handles fields not present in initial data (new insert)" do
      data = %TestSchema{}

      changeset = %Ecto.Changeset{
        data: data,
        changes: %{name: "John", email: "john@example.com", age: 30}
      }

      assert EctoRepoWrapper.get_initial_data(changeset) == %{
               name: nil,
               email: nil,
               age: nil
             }
    end
  end

  describe "get_changes/1 - nested associations" do
    test "does not include primary key for root changeset" do
      changeset =
        User.changeset(%User{id: 5}, %{
          name: "John"
        })

      changes = EctoRepoWrapper.get_changes(changeset)

      refute Map.has_key?(changes, :id)
      assert changes == %{name: "John"}
    end

    test "includes only changed fields for new nested has_one association" do
      changeset =
        User.changeset(%User{}, %{
          name: "Alice",
          email: "alice@example.com",
          profile: %{bio: "Engineer", avatar_url: "https://example.com/avatar.jpg"}
        })

      changes = EctoRepoWrapper.get_changes(changeset)

      # No artificial PK - only changed fields
      assert changes.profile == %{
               bio: "Engineer",
               avatar_url: "https://example.com/avatar.jpg"
             }
    end

    test "includes only changed fields for updated nested has_one association" do
      existing_profile = %Profile{id: 5, bio: "Old bio", avatar_url: "old.jpg"}
      user = %User{id: 10, profile: existing_profile}

      changeset =
        User.changeset(user, %{
          profile: %{id: 5, bio: "New bio"}
        })

      changes = EctoRepoWrapper.get_changes(changeset)

      # Only bio changed (ID didn't change)
      assert changes.profile == %{bio: "New bio"}
    end

    test "includes only changed fields for new nested has_many items" do
      changeset =
        User.changeset(%User{}, %{
          name: "Bob",
          email: "bob@example.com",
          posts: [
            %{title: "Post 1", body: "Content 1"},
            %{title: "Post 2", body: "Content 2"}
          ]
        })

      changes = EctoRepoWrapper.get_changes(changeset)

      assert length(changes.posts) == 2
      # No artificial PK - only changed fields
      assert Enum.at(changes.posts, 0) == %{title: "Post 1", body: "Content 1"}
      assert Enum.at(changes.posts, 1) == %{title: "Post 2", body: "Content 2"}
    end

    test "includes only changed fields for updated has_many items" do
      existing_post = %Post{id: 3, title: "Old Title", body: "Old Content"}
      user = %User{id: 10, posts: [existing_post]}

      changeset =
        User.changeset(user, %{
          posts: [%{id: 3, title: "New Title"}]
        })

      changes = EctoRepoWrapper.get_changes(changeset)

      # Only title changed (ID and body didn't change)
      assert [%{title: "New Title"}] = changes.posts
    end

    test "handles mixed create and update in has_many" do
      existing_post = %Post{id: 3, title: "Existing", body: "Content"}
      user = %User{id: 10, posts: [existing_post]}

      changeset =
        User.changeset(user, %{
          posts: [
            %{id: 3, title: "Updated Title"},
            %{title: "New Post", body: "New Content"}
          ]
        })

      changes = EctoRepoWrapper.get_changes(changeset)

      assert length(changes.posts) == 2
      # No PKs - operation type detection removed
      assert Enum.at(changes.posts, 0) == %{title: "Updated Title"}
      assert Enum.at(changes.posts, 1) == %{title: "New Post", body: "New Content"}
    end
  end

  describe "get_initial_data/1 - nested associations" do
    test "returns nil for NotLoaded has_one association" do
      changeset =
        User.changeset(%User{}, %{
          name: "Alice",
          profile: %{bio: "Engineer"}
        })

      initial_data = EctoRepoWrapper.get_initial_data(changeset)

      assert initial_data.profile == nil
    end

    test "returns empty list for NotLoaded has_many association" do
      changeset =
        User.changeset(%User{}, %{
          name: "Bob",
          posts: [%{title: "Post 1"}]
        })

      initial_data = EctoRepoWrapper.get_initial_data(changeset)

      assert initial_data.posts == []
    end

    test "returns only changed fields for updated has_one association" do
      existing_profile = %Profile{
        id: 5,
        bio: "Old bio",
        avatar_url: "old.jpg",
        user_id: 10
      }

      user = %User{id: 10, profile: existing_profile}

      changeset =
        User.changeset(user, %{
          profile: %{id: 5, bio: "New bio"}
        })

      initial_data = EctoRepoWrapper.get_initial_data(changeset)

      # Only changed fields (bio changed, ID didn't)
      assert initial_data.profile == %{bio: "Old bio"}
    end

    test "returns only changed fields for updated has_many items" do
      existing_post = %Post{
        id: 3,
        title: "Old Title",
        body: "Old Content",
        user_id: 10
      }

      user = %User{id: 10, posts: [existing_post]}

      changeset =
        User.changeset(user, %{
          posts: [%{id: 3, title: "New Title"}]
        })

      initial_data = EctoRepoWrapper.get_initial_data(changeset)

      # Only changed fields (title changed, ID and body didn't)
      assert initial_data.posts == [%{title: "Old Title"}]
    end

    test "mirrors changes structure for has_many" do
      existing_post = %Post{id: 3, title: "Existing", body: "Content"}
      user = %User{id: 10, posts: [existing_post]}

      changeset =
        User.changeset(user, %{
          posts: [
            %{id: 3, title: "Updated"},
            %{title: "New Post", body: "New Content"}
          ]
        })

      initial_data = EctoRepoWrapper.get_initial_data(changeset)

      # Mirrors changes structure - same number of items
      # First item: old value for updated item
      # Second item: old value for new item (didn't exist)
      assert length(initial_data.posts) == 2
      assert Enum.at(initial_data.posts, 0) == %{title: "Existing"}
      # Note: Second item position-matched with empty initial struct
    end

    test "handles multiple fields updated in same has_one association" do
      existing_profile = %Profile{
        id: 5,
        bio: "Old bio",
        avatar_url: "old.jpg"
      }

      user = %User{id: 10, profile: existing_profile}

      changeset =
        User.changeset(user, %{
          profile: %{id: 5, bio: "New bio", avatar_url: "new.jpg"}
        })

      initial_data = EctoRepoWrapper.get_initial_data(changeset)

      # Only changed fields (bio and avatar_url changed, ID didn't)
      assert initial_data.profile == %{
               bio: "Old bio",
               avatar_url: "old.jpg"
             }
    end
  end
end
