defmodule ExEventBus.EmbeddedSchemaTest do
  use ExUnit.Case, async: true

  alias ExEventBus.EctoRepoWrapper
  alias ExEventBus.Schemas.Document
  alias ExEventBus.Schemas.Picture

  describe "get_changes/1 with embeds_one" do
    test "includes only changed fields for new embedded schema" do
      changeset =
        Document.changeset(%Document{}, %{
          title: "My Document",
          content: "Some content",
          picture: %{
            url: "https://example.com/avatar.jpg"
          }
        })

      changes = EctoRepoWrapper.get_changes(changeset)

      # Only changed fields, no artificial ID addition
      assert changes[:picture][:url] == "https://example.com/avatar.jpg"
      refute Map.has_key?(changes[:picture], :id)
    end

    test "includes only changed fields for updated embedded schema" do
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

      # Only changed fields (URL changed, ID didn't)
      assert changes[:picture][:url] == "https://example.com/new.jpg"
      refute Map.has_key?(changes[:picture], :id)
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

    test "returns old values for changed fields in updated embedded schema" do
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

      # Only old values for changed fields (URL changed, ID didn't)
      assert initial_data[:picture][:url] == "https://example.com/old.jpg"
      refute Map.has_key?(initial_data[:picture], :id)
    end

    test "handles updating embedded schema - mirrors changes structure" do
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

      # Only changed fields in changes (URL)
      assert changes[:picture][:url] == "https://example.com/completely-new.jpg"
      refute Map.has_key?(changes[:picture], :id)

      # Initial data mirrors changes structure
      assert initial_data[:picture][:url] == "https://example.com/old.jpg"
      refute Map.has_key?(initial_data[:picture], :id)
    end
  end
end
