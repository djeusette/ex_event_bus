defmodule EventBus.TestStruct do
  @moduledoc """
  Defines a struct to test the EventBus serialization
  """

  @derive JSON.Encoder
  defstruct([:id, :name, :inserted_at])
end
