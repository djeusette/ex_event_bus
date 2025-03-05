defmodule ExEventBus.Testing do
  @moduledoc """
  Defines functions to perform event assertions
  """

  defmacro __using__(opts) do
    if not Keyword.has_key?(opts, :ex_event_bus) do
      raise ArgumentError, "testing requires a :ex_event_bus option to be set"
    end

    quote do
      @event_bus Keyword.fetch!(unquote(opts), :ex_event_bus)
      @repo @event_bus.repo()

      use Oban.Testing, repo: @repo

      def assert_event_received(event, opts \\ [], timeout \\ :none),
        do: assert_enqueued(build_oban_opts(event, opts), timeout)

      def refute_event_received(event, opts \\ [], timeout \\ :none),
        do: refute_enqueued(build_oban_opts(event, opts), timeout)

      def execute_events(opts \\ []) do
        Oban.drain_queue(
          @event_bus.Oban,
          opts
          |> Keyword.put_new(:queue, :ex_event_bus)
          |> Keyword.put(:with_safety, false)
        )
      end

      defp build_oban_opts(event, opts) do
        args =
          Keyword.get(opts, :args, %{})
          |> Map.put(:event, event)

        opts
        |> Keyword.put(:queue, :ex_event_bus)
        |> Keyword.put(:worker, ExEventBus.Worker)
        |> Keyword.put(:args, args)
      end
    end
  end
end
