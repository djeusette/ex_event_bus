defmodule ExEventBus.EmbeddedSchemaTest do
  use ExUnit.Case, async: true

  alias ExEventBus.EctoRepoWrapper
  alias ExEventBus.Schemas.Document
  alias ExEventBus.Schemas.Picture

  describe "get_changes/1 with embeds_one" do
    test "includes ID for new embedded schema (nil before insert)" do
      changeset =
        Document.changeset(%Document{}, %{
          title: "My Document",
          content: "Some content",
          picture: %{
            url: "https://example.com/avatar.jpg"
          }
        })

      changes = EctoRepoWrapper.get_changes(changeset)

      # Embedded picture MUST have id field
      # Note: ID is nil in changeset, but after insert it will be synced with actual generated ID
      assert Map.has_key?(changes[:picture], :id)
      assert changes[:picture][:id] == nil
      assert changes[:picture][:url] == "https://example.com/avatar.jpg"
    end

    test "includes ID for updated embedded schema to indicate UPDATE" do
      existing_picture_id = Ecto.UUID.generate()

      existing_document = %Document{
        id: Ecto.UUID.generate(),
        title: "My Document",
        content: "Some content",
        picture: %Picture{
          id: existing_picture_id,
          url: "https://example.com/old.jpg"
        }
      }

      changeset =
        Document.changeset(existing_document, %{
          picture: %{
            id: existing_picture_id,
            url: "https://example.com/new.jpg"
          }
        })

      changes = EctoRepoWrapper.get_changes(changeset)

      # Embedded picture MUST have id field with value (indicates UPDATE)
      assert Map.has_key?(changes[:picture], :id)
      assert changes[:picture][:id] == existing_picture_id
      assert changes[:picture][:url] == "https://example.com/new.jpg"
    end

    test "embedded schema without changes is not in changes map" do
      existing_picture_id = Ecto.UUID.generate()

      existing_document = %Document{
        id: Ecto.UUID.generate(),
        title: "My Document",
        content: "Some content",
        picture: %Picture{
          id: existing_picture_id,
          url: "https://example.com/avatar.jpg"
        }
      }

      changeset = Document.changeset(existing_document, %{title: "Updated Title"})

      changes = EctoRepoWrapper.get_changes(changeset)

      assert changes[:title] == "Updated Title"
      refute Map.has_key?(changes, :picture)
    end
  end

  describe "get_initial_data/1 with embeds_one" do
    test "returns nil for new embedded schema" do
      changeset =
        Document.changeset(%Document{}, %{
          title: "My Document",
          picture: %{
            url: "https://example.com/avatar.jpg"
          }
        })

      initial_data = EctoRepoWrapper.get_initial_data(changeset)

      assert initial_data[:title] == nil
      assert initial_data[:picture] == nil
    end

    test "returns old values for updated embedded schema" do
      existing_picture_id = Ecto.UUID.generate()

      existing_document = %Document{
        id: Ecto.UUID.generate(),
        title: "My Document",
        content: "Some content",
        picture: %Picture{
          id: existing_picture_id,
          url: "https://example.com/old.jpg"
        }
      }

      changeset =
        Document.changeset(existing_document, %{
          picture: %{
            id: existing_picture_id,
            url: "https://example.com/new.jpg"
          }
        })

      initial_data = EctoRepoWrapper.get_initial_data(changeset)

      assert Map.has_key?(initial_data[:picture], :id)
      assert initial_data[:picture][:id] == existing_picture_id
      assert initial_data[:picture][:url] == "https://example.com/old.jpg"
    end

    test "handles updating embedded schema - on_replace: :update keeps same ID" do
      existing_picture_id = Ecto.UUID.generate()

      existing_document = %Document{
        id: Ecto.UUID.generate(),
        title: "My Document",
        content: "Some content",
        picture: %Picture{
          id: existing_picture_id,
          url: "https://example.com/old.jpg"
        }
      }

      # Update picture (on_replace: :update means it updates existing, not creates new)
      changeset =
        Document.changeset(existing_document, %{
          picture: %{
            url: "https://example.com/completely-new.jpg"
          }
        })

      changes = EctoRepoWrapper.get_changes(changeset)
      initial_data = EctoRepoWrapper.get_initial_data(changeset)

      # Picture MUST have id field (same ID = UPDATE, not CREATE)
      assert Map.has_key?(changes[:picture], :id)
      assert changes[:picture][:id] == existing_picture_id
      assert changes[:picture][:url] == "https://example.com/completely-new.jpg"

      # Initial data should show the old picture with same ID
      assert Map.has_key?(initial_data[:picture], :id)
      assert initial_data[:picture][:id] == existing_picture_id
      assert initial_data[:picture][:url] == "https://example.com/old.jpg"
    end
  end
end
