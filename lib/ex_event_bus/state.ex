defmodule ExEventBus.State do
  @moduledoc """
  Uses ETS to define the state of the event bus, particularly the 
  subscribers for each event.
  """

  def child_spec(opts) do
    {name, opts} = Keyword.pop!(opts, :name)

    Supervisor.child_spec(
      {
        ConCache,
        [
          name: name,
          ttl_check_interval: false
        ]
        |> Keyword.merge(opts)
      },
      id: {ConCache, name}
    )
  end

  def add_subscriber(cache_id, event_module, subscriber_module) do
    ConCache.update(cache_id, event_module, fn
      nil ->
        {:ok, [subscriber_module]}

      [_ | _] = existing_subscribers ->
        {:ok, Enum.uniq([subscriber_module | existing_subscribers])}
    end)
  end

  def get_subscribers(cache_id, event_module) do
    case ConCache.get(cache_id, event_module) do
      nil -> []
      subscribers -> subscribers
    end
  end
end
