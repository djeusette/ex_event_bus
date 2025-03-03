defmodule EventBus.EventHandler do
  @moduledoc false

  alias __MODULE__

  @callback handle_event(EventBus.Event.t()) :: :ok | {:ok, any} | :error | {:error, any}

  defmacro __using__(opts) do
    if not Keyword.has_key?(opts, :event_bus) do
      raise ArgumentError, "EventHandler requires a :event_bus option to be set"
    end

    quote bind_quoted: [opts: opts], location: :keep do
      use GenServer, restart: :transient
      use EventBus.Event

      @opts opts
      @event_bus Keyword.fetch!(opts, :event_bus)

      def start_link(opts),
        do: GenServer.start_link(__MODULE__, Keyword.merge(opts, @opts), name: __MODULE__)

      def init(opts) do
        events = Keyword.get(opts, :events, [])

        # Add the handler has a subscriber to the provided events
        Enum.each(events, fn event -> @event_bus.subscribe(event, __MODULE__) end)

        {:ok, %{events: events}}
      end

      Elixir.Kernel.@(behaviour(EventHandler))

      @impl EventHandler
      def handle_event(_event), do: raise("Not implemented")

      defoverridable handle_event: 1
    end
  end
end
