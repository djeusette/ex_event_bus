defmodule EventBus do
  @moduledoc """
  The event bus dispatches events to subscribers.
  It uses Oban behind the scenes to ensure exactly once delivery.
  """

  alias __MODULE__.Publisher
  alias __MODULE__.State

  defmacro __using__(opts) do
    if not Keyword.has_key?(opts, :otp_app) do
      raise ArgumentError, "EventBus requires a :otp_app option to be set"
    end

    quote bind_quoted: [opts: opts], location: :keep do
      use Supervisor
      use EventBus.Event

      @opts opts
      @otp_app Keyword.fetch!(opts, :otp_app)

      def start_link(_opts) do
        Supervisor.start_link(__MODULE__, @opts, name: __MODULE__)
      end

      def children(opts) do
        [
          {Oban, oban_config(opts)},
          {State, [name: __MODULE__.State]}
        ]
      end

      @impl Supervisor
      def init(opts),
        do: Supervisor.init(children(opts), strategy: :one_for_one)

      def subscribe(event_mod, subscriber) when is_atom(event_mod) do
        EventBus.State.add_subscriber(__MODULE__.State, event_mod, subscriber)
      end

      def subscribe(event_mod, subscriber) when is_binary(event_mod) do
        EventBus.State.add_subscriber(
          __MODULE__.State,
          String.to_existing_atom(event_mod),
          subscriber
        )
      end

      def subscribers(event) when is_event(event),
        do: State.get_subscribers(__MODULE__.State, event.__struct__)

      def subscribers(event_mod) when is_atom(event_mod),
        do: State.get_subscribers(__MODULE__.State, event_mod)

      @spec publish(event :: EventBus.Event.t() | list(EventBus.Event.t())) :: list(Oban.Job.t())
      def publish(event),
        do: Publisher.publish(__MODULE__.Oban, create_job_changesets_for_events(List.wrap(event)))

      @spec publish(
              multi :: Ecto.Multi.t(),
              event :: EventBus.Event.t() | list(EventBus.Event.t())
            ) ::
              multi :: Ecto.Multi.t()
      def publish(%Ecto.Multi{} = multi, event),
        do:
          Publisher.publish(__MODULE__.Oban, create_job_changesets_for_events(List.wrap(event)),
            multi: multi
          )

      def repo do
        oban_config(@opts)
        |> Keyword.fetch!(:repo)
      end

      defp create_job_changesets_for_event(event) when is_event(event),
        do: Publisher.create_job_changesets(subscribers(event), event)

      defp create_job_changesets_for_events(events, acc \\ [])

      defp create_job_changesets_for_events([first_event | other_events] = _events, acc),
        do:
          create_job_changesets_for_events(
            other_events,
            concat_lists(create_job_changesets_for_event(first_event), acc)
          )

      defp create_job_changesets_for_events([], acc), do: Enum.reverse(acc)

      defp concat_lists([first | rest], acc) do
        concat_lists(rest, [first | acc])
      end

      defp concat_lists([], acc), do: acc

      defp oban_config(opts) do
        Keyword.get_lazy(opts, :oban, fn ->
          Application.fetch_env!(@otp_app, __MODULE__)
          |> Keyword.get(:oban)
        end)
        |> Keyword.put(:name, __MODULE__.Oban)
      end
    end
  end
end
