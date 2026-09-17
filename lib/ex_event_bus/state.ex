defmodule ExEventBus.State do
  @moduledoc """
  The subscriber registry of an event bus.

  Subscriptions are written once, when each handler starts, and read on every
  publish, so they live in `:persistent_term` rather than in a process: no
  restart of the bus, of its Oban instance or of a handler can empty the
  registry, and a publish never finds a registry that is being rebuilt.

  The registry is global to the node and keyed by bus, so it outlives any
  single bus process. Test suites that start a bus per test call `clear/1` to
  reset it.
  """

  @doc """
  Registers `subscriber_module` for `event_module` on `bus`.

  Idempotent: registering the same subscriber twice keeps a single entry,
  moved to the front of the list.
  """
  @spec add_subscriber(bus :: atom, event_module :: atom, subscriber_module :: atom) :: :ok
  def add_subscriber(bus, event_module, subscriber_module)
      when is_atom(bus) and is_atom(event_module) and is_atom(subscriber_module) do
    key = key(bus, event_module)
    subscribers = Enum.uniq([subscriber_module | :persistent_term.get(key, [])])

    :persistent_term.put(key, subscribers)
  end

  @doc """
  Returns the subscribers registered for `event_module` on `bus`, most recently
  registered first, or `[]` when there are none.
  """
  @spec get_subscribers(bus :: atom, event_module :: atom) :: list(atom)
  def get_subscribers(bus, event_module) when is_atom(bus) and is_atom(event_module) do
    :persistent_term.get(key(bus, event_module), [])
  end

  @doc """
  Removes every subscription registered on `bus`, leaving other buses untouched.
  """
  @spec clear(bus :: atom) :: :ok
  def clear(bus) when is_atom(bus) do
    :persistent_term.get()
    |> Enum.each(&maybe_erase(&1, bus))
  end

  defp maybe_erase({{__MODULE__, bus, _event_module} = key, _subscribers}, bus),
    do: :persistent_term.erase(key)

  defp maybe_erase(_entry, _bus), do: :ok

  defp key(bus, event_module), do: {__MODULE__, bus, event_module}
end
