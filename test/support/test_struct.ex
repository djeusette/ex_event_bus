defmodule ExEventBus.TestStruct do
  @moduledoc """
  Defines a struct to test the ExEventBus serialization
  """

  @derive JSON.Encoder
  defstruct([:id, :name, :inserted_at])
end
